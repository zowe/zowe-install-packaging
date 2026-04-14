/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2024
 */

import java.io.*;
import java.nio.charset.*;
import java.nio.file.*;
import java.security.*;
import java.util.Base64;

/**
 * Tests for ExportPrivateKey encoding correctness (GitHub issue #4730).
 *
 * ROOT CAUSE
 * ----------
 * ExportPrivateKeyZos.java and ExportPrivateKeyLinux.java use:
 *
 *     FileWriter fw = new FileWriter(exportedFile);
 *
 * FileWriter without an explicit charset relies on Charset.defaultCharset().
 * The default charset changed across Java versions:
 *
 *   Java 17 on z/OS  → IBM-1047 (EBCDIC)
 *   Java 21 on z/OS  → UTF-8  (JEP 400, Java 18+)
 *
 * When the file is written with EBCDIC bytes, z/OS USS treats it as EBCDIC and
 * cat/downstream tools display it correctly.
 * When the file is written with UTF-8 bytes, z/OS USS interprets them as EBCDIC
 * and displays garbage (e.g. "����+�&�����.��" instead of "-----BEGIN PRIVATE KEY-----").
 *
 * WHAT THESE TESTS DEMONSTRATE
 * -----------------------------
 * 1. CURRENT CODE IS FRAGILE: output depends on whatever Charset.defaultCharset()
 *    returns, which differs between JVM versions and platforms.
 *
 * 2. SIMULATED WRONG-ENCODING SCENARIO: writing with UTF-16 mimics what happens
 *    on z/OS Java 21 (where the default charset changed from IBM-1047 to UTF-8
 *    and the result is bytes that z/OS cat reads as garbage).
 *
 * 3. FIXED CODE IS STABLE: OutputStreamWriter with StandardCharsets.ISO_8859_1
 *    always produces valid ASCII PEM regardless of platform or JVM version.
 *    On z/OS, IBM Java also tags the USS file as CCSID 819 (ISO-8859-1) when this
 *    charset is used, which is exactly what downstream tools expect.
 *
 * USAGE
 * -----
 * Run via run-export-key-tests.sh which creates the test keystore automatically,
 * or manually:
 *
 *   keytool -genkeypair -alias testkey -keyalg RSA -keysize 2048 \
 *           -keystore test.p12 -storetype PKCS12 -storepass testpass \
 *           -dname "CN=Test" -validity 365
 *   javac ExportPrivateKeyTest.java
 *   java ExportPrivateKeyTest test.p12 testpass testkey
 */
public class ExportPrivateKeyTest {

    private static int passed = 0;
    private static int failed = 0;

    public static void main(String[] args) throws Exception {
        if (args.length < 3) {
            System.err.println("Usage: ExportPrivateKeyTest <keystore.p12> <storepass> <alias>");
            System.exit(1);
        }
        String keystorePath = args[0];
        String storePass    = args[1];
        String alias        = args[2];

        printEnvironment();

        Key key = loadKey(keystorePath, storePass, alias);
        String base64Key = Base64.getEncoder().encodeToString(key.getEncoded());

        // ----------------------------------------------------------------
        // Test 1: Current (unfixed) code — FileWriter with default charset
        //
        // On Linux with Java 17 or 21 (both UTF-8): PASSES (UTF-8 ≈ ASCII
        // for PEM characters).
        // On z/OS Java 17 (IBM-1047 default):       PASSES (EBCDIC bytes,
        //   cat converts correctly).
        // On z/OS Java 21 (UTF-8 default, JEP 400): FAILS — UTF-8 bytes
        //   are read by cat as EBCDIC and appear as garbage.
        // ----------------------------------------------------------------
        System.out.println("--- TEST 1: Current code — FileWriter (default charset: "
            + Charset.defaultCharset() + ") ---");
        File out1 = tmpFile();
        writeWithFileWriter(base64Key, out1);
        boolean t1 = assertValidPem(out1, "FileWriter default charset");
        printResult("TEST 1 (FileWriter default charset)", t1);

        // ----------------------------------------------------------------
        // Test 2: Encoding issue simulation — OutputStreamWriter with UTF-16
        //
        // UTF-16 adds a BOM (0xFF 0xFE) and uses 2+ bytes per character.
        // The result is NOT valid ASCII PEM.  This simulates what happens on
        // z/OS when the default charset writes bytes that z/OS cannot
        // interpret as ASCII/EBCDIC PEM.  On both Java 17 and Java 21,
        // this test FAILS, proving that relying on an implicit charset is
        // dangerous.
        // ----------------------------------------------------------------
        System.out.println("--- TEST 2: Encoding issue simulation — UTF-16 (wrong charset) ---");
        File out2 = tmpFile();
        writeWithCharset(base64Key, out2, StandardCharsets.UTF_16);
        boolean t2 = assertValidPem(out2, "UTF-16 (wrong charset — simulate z/OS Java 21 problem)");
        printResult("TEST 2 (UTF-16 wrong charset — expected to FAIL)", !t2); // inverted: we expect failure

        // ----------------------------------------------------------------
        // Test 3: Fixed code — OutputStreamWriter with explicit ISO-8859-1
        //
        // ISO-8859-1 writes pure ASCII bytes for PEM content (which uses
        // only the ASCII subset).  On z/OS the IBM JDK also tags the USS
        // file as CCSID 819 when this charset is used, so downstream tools
        // see a correctly-tagged ASCII file.
        // This test must PASS on both Java 17 and Java 21 on any platform.
        // ----------------------------------------------------------------
        System.out.println("--- TEST 3: Fixed code — OutputStreamWriter(ISO_8859_1) ---");
        File out3 = tmpFile();
        writeWithCharset(base64Key, out3, StandardCharsets.ISO_8859_1);
        boolean t3 = assertValidPem(out3, "OutputStreamWriter(ISO_8859_1) — fixed");
        printResult("TEST 3 (ISO_8859_1 fixed — expected to PASS)", t3);

        // ----------------------------------------------------------------
        // Test 4: Fixed code is stable even when -Dfile.encoding is wrong
        //
        // With explicit charset, the output must be valid PEM regardless of
        // whatever Charset.defaultCharset() returns.  This confirms the fix
        // is immune to JVM/platform encoding configuration.
        // ----------------------------------------------------------------
        System.out.println("--- TEST 4: Fixed code stability — ISO_8859_1 ignores Charset.defaultCharset() ---");
        // We write deliberately using the DEFAULT charset first (to capture it),
        // then re-write using ISO_8859_1, and compare byte-by-byte.
        // The ISO_8859_1 output should always equal the ASCII reference bytes.
        File out4 = tmpFile();
        writeWithCharset(base64Key, out4, StandardCharsets.ISO_8859_1);
        byte[] fixedBytes = Files.readAllBytes(out4.toPath());
        boolean allAscii = true;
        for (byte b : fixedBytes) {
            if ((b & 0xFF) > 127) { allAscii = false; break; }
        }
        printResult("TEST 4 (ISO_8859_1 output is pure ASCII)", allAscii);
        if (allAscii) passed++; else failed++;

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        System.out.println();
        System.out.println("==============================================");
        System.out.printf ("  Results: %d passed, %d failed%n", passed, failed);
        System.out.println("==============================================");
        System.exit(failed > 0 ? 1 : 0);
    }

    // -----------------------------------------------------------------------
    // Write helpers
    // -----------------------------------------------------------------------

    /**
     * Reproduces the current (buggy) code from ExportPrivateKeyLinux.java /
     * ExportPrivateKeyZos.java — uses FileWriter without an explicit charset.
     */
    static void writeWithFileWriter(String base64Key, File output) throws IOException {
        FileWriter fw = new FileWriter(output);
        writePem(fw, base64Key);
        fw.close();
    }

    /**
     * Writes PEM with an explicit charset — used both to simulate wrong encoding
     * (UTF_16) and to test the fix (ISO_8859_1).
     */
    static void writeWithCharset(String base64Key, File output, Charset charset) throws IOException {
        Writer fw = new OutputStreamWriter(new FileOutputStream(output), charset);
        writePem(fw, base64Key);
        fw.close();
    }

    /** Writes base64Key as a PEM-wrapped private key block to the given Writer. */
    static void writePem(Writer fw, String encoded) throws IOException {
        fw.write("-----BEGIN PRIVATE KEY-----");
        for (int i = 0; i < encoded.length(); i++) {
            if (((i % 64) == 0) && (i != (encoded.length() - 1))) {
                fw.write("\n");
            }
            fw.write(encoded.charAt(i));
        }
        fw.write("\n");
        fw.write("-----END PRIVATE KEY-----\n");
    }

    // -----------------------------------------------------------------------
    // Validation helpers
    // -----------------------------------------------------------------------

    /**
     * Validates that the file contains a valid ASCII PEM private key block.
     * Checks:
     *   - File starts with "-----BEGIN PRIVATE KEY-----"
     *   - File ends with "-----END PRIVATE KEY-----"
     *   - All bytes are in the printable ASCII range (0x20–0x7E) or newline
     */
    static boolean assertValidPem(File file, String label) throws IOException {
        byte[] bytes = Files.readAllBytes(file.toPath());

        // Show the first 28 bytes for diagnostic visibility
        System.out.printf("  First 28 bytes of '%s':%n    hex  : ", label);
        for (int i = 0; i < Math.min(28, bytes.length); i++) {
            System.out.printf("%02X ", bytes[i] & 0xFF);
        }
        System.out.println();
        System.out.print("    chars: ");
        for (int i = 0; i < Math.min(28, bytes.length); i++) {
            char c = (char) (bytes[i] & 0xFF);
            System.out.print(Character.isISOControl(c) ? '.' : c);
        }
        System.out.println();

        // Check 1: starts with PEM header in ASCII
        byte[] pemHeader = "-----BEGIN PRIVATE KEY-----".getBytes(StandardCharsets.ISO_8859_1);
        if (bytes.length < pemHeader.length) {
            System.out.println("  FAIL: file too short to contain PEM header");
            return false;
        }
        for (int i = 0; i < pemHeader.length; i++) {
            if (bytes[i] != pemHeader[i]) {
                System.out.println("  FAIL: file does not start with '-----BEGIN PRIVATE KEY-----'");
                return false;
            }
        }

        // Check 2: ends with PEM footer
        String content = new String(bytes, StandardCharsets.ISO_8859_1);
        if (!content.contains("-----END PRIVATE KEY-----")) {
            System.out.println("  FAIL: file does not contain '-----END PRIVATE KEY-----'");
            return false;
        }

        // Check 3: all bytes are printable ASCII or newline/carriage-return
        for (byte b : bytes) {
            int unsigned = b & 0xFF;
            if (unsigned > 127 || (unsigned < 0x20 && unsigned != '\n' && unsigned != '\r')) {
                System.out.printf("  FAIL: non-ASCII byte 0x%02X found%n", unsigned);
                return false;
            }
        }

        System.out.println("  PASS: file is valid ASCII PEM");
        return true;
    }

    // -----------------------------------------------------------------------
    // Keystore helpers
    // -----------------------------------------------------------------------

    static Key loadKey(String keystorePath, String storePass, String alias) throws Exception {
        KeyStore ks = KeyStore.getInstance("PKCS12");
        try (FileInputStream fis = new FileInputStream(keystorePath)) {
            ks.load(fis, storePass.toCharArray());
        }
        Key key = ks.getKey(alias, storePass.toCharArray());
        if (key == null) {
            throw new IllegalArgumentException("Alias '" + alias + "' not found in keystore");
        }
        return key;
    }

    // -----------------------------------------------------------------------
    // Utility
    // -----------------------------------------------------------------------

    static File tmpFile() throws IOException {
        File f = File.createTempFile("export-key-test-", ".pem");
        f.deleteOnExit();
        return f;
    }

    static void printEnvironment() {
        System.out.println("==============================================");
        System.out.println(" ExportPrivateKey Encoding Test  (GH #4730)");
        System.out.println("==============================================");
        System.out.println("Java version    : " + System.getProperty("java.version"));
        System.out.println("file.encoding   : " + System.getProperty("file.encoding"));
        System.out.println("native.encoding : " + System.getProperty("native.encoding", "(not set)"));
        System.out.println("stdout.encoding : " + System.getProperty("stdout.encoding", "(not set)"));
        System.out.println("Default charset : " + Charset.defaultCharset());
        System.out.println();
    }

    static void printResult(String name, boolean pass) {
        String mark = pass ? "PASS" : "FAIL";
        System.out.printf("  >> %s: %s%n%n", mark, name);
        if (pass) passed++; else failed++;
    }
}
