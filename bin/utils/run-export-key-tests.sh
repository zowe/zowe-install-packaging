#!/bin/sh
# run-export-key-tests.sh
#
# Tests for ExportPrivateKey encoding correctness (GitHub issue #4730).
#
# Requires sdkman with Java 17 and Java 21 installed:
#   sdk install java 17.x.x
#   sdk install java 21.x.x
#
# Usage:
#   cd bin/utils
#   sh run-export-key-tests.sh

set -e

JAVA17=$(ls -d "$HOME/.sdkman/candidates/java/17"* 2>/dev/null | head -1)/bin/java
JAVA21=$(ls -d "$HOME/.sdkman/candidates/java/21"* 2>/dev/null | head -1)/bin/java
JAVAC17=$(ls -d "$HOME/.sdkman/candidates/java/17"* 2>/dev/null | head -1)/bin/javac
JAVAC21=$(ls -d "$HOME/.sdkman/candidates/java/21"* 2>/dev/null | head -1)/bin/javac
KEYTOOL=$(ls -d "$HOME/.sdkman/candidates/java/17"* 2>/dev/null | head -1)/bin/keytool

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

KEYSTORE="$WORKDIR/test.p12"
STOREPASS="testpassword"
ALIAS="testkey"

PASS=0
FAIL=0

# ─── helpers ───────────────────────────────────────────────────────────────

die() { echo "ERROR: $*" >&2; exit 1; }

check_head() {
    # check_head <file> <expected_prefix> <label>
    file="$1"
    expected="$2"
    label="$3"
    actual=$(head -c 27 "$file" 2>/dev/null || true)
    if [ "$actual" = "$expected" ]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "        expected : '$expected'"
        printf  "        actual   : '"
        head -c 27 "$file" | od -c | head -2
        printf  "'\n"
        FAIL=$((FAIL + 1))
    fi
}

section() {
    echo ""
    echo "══════════════════════════════════════════════════"
    echo "  $*"
    echo "══════════════════════════════════════════════════"
}

# ─── setup ─────────────────────────────────────────────────────────────────

section "Setup"

[ -x "$JAVA17"    ] || die "Java 17 not found at: $JAVA17"
[ -x "$JAVA21"    ] || die "Java 21 not found at: $JAVA21"
[ -x "$JAVAC17"   ] || die "javac 17 not found"
[ -x "$JAVAC21"   ] || die "javac 21 not found"
[ -x "$KEYTOOL"   ] || die "keytool not found"

echo "Java 17  : $("$JAVA17"  -version 2>&1 | head -1)"
echo "Java 21  : $("$JAVA21"  -version 2>&1 | head -1)"
echo ""

echo "Creating test PKCS12 keystore..."
"$KEYTOOL" -genkeypair \
    -alias       "$ALIAS" \
    -keyalg      RSA \
    -keysize     2048 \
    -keystore    "$KEYSTORE" \
    -storetype   PKCS12 \
    -storepass   "$STOREPASS" \
    -keypass     "$STOREPASS" \
    -dname       "CN=Test, OU=Zowe, O=Test, L=Test, S=Test, C=US" \
    -validity    365 \
    2>/dev/null
echo "Keystore created: $KEYSTORE"

# ─── compile with each Java version ─────────────────────────────────────────

section "Compile"

# Compile ExportPrivateKeyLinux.java with Java 17
"$JAVAC17" -d "$WORKDIR" "$SCRIPT_DIR/ExportPrivateKeyLinux.java"
echo "ExportPrivateKeyLinux compiled with Java 17"

# Compile ExportPrivateKeyTest.java with Java 17 (runs on both JVMs)
"$JAVAC17" -d "$WORKDIR" "$SCRIPT_DIR/ExportPrivateKeyTest.java"
echo "ExportPrivateKeyTest compiled with Java 17"

# ─── part 1: ExportPrivateKeyLinux — Java 17 vs Java 21 ─────────────────────

section "Part 1: ExportPrivateKeyLinux — default encoding, Java 17 vs Java 21"
echo ""
echo "On Linux both Java 17 and Java 21 default to UTF-8, so both should"
echo "produce valid PEM.  On z/OS, Java 17 defaults to IBM-1047 (EBCDIC)"
echo "and Java 21 to UTF-8 — causing the issue reported in GH #4730."
echo ""

OUT17="$WORKDIR/out17.pem"
OUT21="$WORKDIR/out21.pem"

echo "Running ExportPrivateKeyLinux with Java 17 (default encoding)..."
"$JAVA17" -cp "$WORKDIR" ExportPrivateKeyLinux \
    "$KEYSTORE" PKCS12 "$STOREPASS" "$ALIAS" "$STOREPASS" "$OUT17"
check_head "$OUT17" "-----BEGIN PRIVATE KEY-----" "Java 17 default encoding produces valid PEM"

echo "Running ExportPrivateKeyLinux with Java 21 (default encoding)..."
"$JAVA21" -cp "$WORKDIR" ExportPrivateKeyLinux \
    "$KEYSTORE" PKCS12 "$STOREPASS" "$ALIAS" "$STOREPASS" "$OUT21"
check_head "$OUT21" "-----BEGIN PRIVATE KEY-----" "Java 21 default encoding produces valid PEM"

# ─── part 2: encoding sensitivity — forcing wrong charset ───────────────────

section "Part 2: Encoding sensitivity — forcing wrong charset"
echo ""
echo "Here we force '-Dfile.encoding=UTF-16' to simulate what happens when"
echo "FileWriter picks a wrong charset (as it does on z/OS Java 21 where the"
echo "default changed from IBM-1047 to UTF-8, causing z/OS cat to read garbage)."
echo ""

OUT17_BAD="$WORKDIR/out17_utf16.pem"
OUT21_BAD="$WORKDIR/out21_utf16.pem"

echo "Running ExportPrivateKeyLinux with Java 17 and -Dfile.encoding=UTF-16..."
"$JAVA17" -Dfile.encoding=UTF-16 -cp "$WORKDIR" ExportPrivateKeyLinux \
    "$KEYSTORE" PKCS12 "$STOREPASS" "$ALIAS" "$STOREPASS" "$OUT17_BAD"
# We expect this to FAIL (not valid PEM) — proving encoding sensitivity
head_17_bad=$(head -c 27 "$OUT17_BAD" 2>/dev/null || true)
if [ "$head_17_bad" != "-----BEGIN PRIVATE KEY-----" ]; then
    echo "  PASS: Java 17 + UTF-16 produces non-PEM output (encoding sensitivity confirmed)"
    PASS=$((PASS + 1))
else
    echo "  NOTE: Java 17 + UTF-16 still produced valid PEM header (charset override may be ignored)"
    # Not a failure of the test — just documenting behavior
fi

echo "Running ExportPrivateKeyLinux with Java 21 and -Dfile.encoding=UTF-16..."
"$JAVA21" -Dfile.encoding=UTF-16 -cp "$WORKDIR" ExportPrivateKeyLinux \
    "$KEYSTORE" PKCS12 "$STOREPASS" "$ALIAS" "$STOREPASS" "$OUT21_BAD"
head_21_bad=$(head -c 27 "$OUT21_BAD" 2>/dev/null || true)
if [ "$head_21_bad" != "-----BEGIN PRIVATE KEY-----" ]; then
    echo "  PASS: Java 21 + UTF-16 produces non-PEM output (encoding sensitivity confirmed)"
    PASS=$((PASS + 1))
else
    echo "  NOTE: Java 21 + UTF-16 still produced valid PEM header"
    echo "        (JEP 400 may override -Dfile.encoding; see ExportPrivateKeyTest for inline charset tests)"
fi

# ─── part 3: ExportPrivateKeyTest — inline charset tests ────────────────────

section "Part 3: ExportPrivateKeyTest — inline charset tests (Java 17)"
echo ""
echo "This tests the export logic directly with:"
echo "  - FileWriter (default charset)     — current buggy code"
echo "  - OutputStreamWriter(UTF-16)       — simulated wrong encoding"
echo "  - OutputStreamWriter(ISO_8859_1)   — the fix"
echo ""

"$JAVA17" -cp "$WORKDIR" ExportPrivateKeyTest "$KEYSTORE" "$STOREPASS" "$ALIAS"
T1_EXIT=$?
if [ $T1_EXIT -eq 0 ]; then
    echo "Overall: ExportPrivateKeyTest PASSED on Java 17"
    PASS=$((PASS + 1))
else
    echo "Overall: ExportPrivateKeyTest had failures on Java 17 (see detail above)"
    FAIL=$((FAIL + 1))
fi

section "Part 3: ExportPrivateKeyTest — inline charset tests (Java 21)"
echo ""

"$JAVA21" -cp "$WORKDIR" ExportPrivateKeyTest "$KEYSTORE" "$STOREPASS" "$ALIAS"
T2_EXIT=$?
if [ $T2_EXIT -eq 0 ]; then
    echo "Overall: ExportPrivateKeyTest PASSED on Java 21"
    PASS=$((PASS + 1))
else
    echo "Overall: ExportPrivateKeyTest had failures on Java 21 (see detail above)"
    FAIL=$((FAIL + 1))
fi

# ─── part 4: compare Java 17 vs Java 21 output bytes ────────────────────────

section "Part 4: Byte-level comparison of Java 17 vs Java 21 output"

if cmp -s "$OUT17" "$OUT21"; then
    echo "  PASS: Java 17 and Java 21 produce identical output (both UTF-8 on Linux)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Java 17 and Java 21 output differs — encoding inconsistency"
    FAIL=$((FAIL + 1))
fi

# ─── summary ─────────────────────────────────────────────────────────────────

section "Summary"
echo ""
echo "  Shell-level checks : passed=$PASS  failed=$FAIL"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  All checks passed."
else
    echo "  Some checks failed — see details above."
fi
echo ""

exit $FAIL
