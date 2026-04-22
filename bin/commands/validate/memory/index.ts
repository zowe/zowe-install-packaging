/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as zosNative from 'zos';   // native QuickJS zos module (provides getEsm())
import * as common from '../../../../libs/common';
import * as shell from '../../../../libs/shell';
import * as zos from '../../../../libs/zos';   // Zowe zos library (provides tsoCommand())

const COMMAND_NAME = 'zwe-validate-memory';

// Sentinel value meaning "no limit / unlimited"
const NOLIMIT = -1;

// ─── Supported ESM types ──────────────────────────────────────────────────────
// Returned by zosNative.getEsm() – the getesm utility binary.
const ESM_RACF  = 'RACF';
const ESM_TSS   = 'TSS';
const ESM_ACF2  = 'ACF2';

// ─── Defaults (sourced from Zowe configure-uss documentation) ────────────────
// ulimit -A is reported in KB (1024-byte units).
const DEFAULT_MIN_ULIMIT_A_KB = 250000;
// OMVS ASSIZEMAX / ASSSIZE is in bytes (all ESMs).
const DEFAULT_MIN_ASSIZEMAX_BYTES = 2147483647;
// OMVS MEMLIMIT – minimum above-the-bar memory. Expressed as a string so
// it can be parsed by parseMemorySize().
const DEFAULT_MIN_MEMLIMIT_STR = '4G';
// TSO region SIZE is in units of 1 KB (all ESMs).
const DEFAULT_MIN_TSO_SIZE = 2096128;
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Parse a z/OS-style memory size string into bytes.
 *
 * Recognised formats:
 *   NOLIMIT, NONE, unlimited  → NOLIMIT sentinel (-1)
 *   <n>G   → n × 2^30 bytes
 *   <n>M   → n × 2^20 bytes
 *   <n>K   → n × 2^10 bytes
 *   <n>    → n bytes
 *
 * Returns NOLIMIT for any value that cannot be parsed.
 */
function parseMemorySize(value: string): number {
  if (!value) return NOLIMIT;
  const trimmed = value.trim().toUpperCase();
  if (trimmed === 'NOLIMIT' || trimmed === 'NONE' || trimmed === 'UNLIMITED') {
    return NOLIMIT;
  }
  if (trimmed.endsWith('G')) {
    const n = parseInt(trimmed, 10);
    return isNaN(n) ? NOLIMIT : n * 1024 * 1024 * 1024;
  }
  if (trimmed.endsWith('M')) {
    const n = parseInt(trimmed, 10);
    return isNaN(n) ? NOLIMIT : n * 1024 * 1024;
  }
  if (trimmed.endsWith('K')) {
    const n = parseInt(trimmed, 10);
    return isNaN(n) ? NOLIMIT : n * 1024;
  }
  const n = parseInt(trimmed, 10);
  return isNaN(n) ? NOLIMIT : n;
}

/**
 * Return a human-readable representation of a byte count.
 */
function formatBytes(bytes: number): string {
  if (bytes === NOLIMIT) return 'unlimited (NOLIMIT)';
  if (bytes >= 1024 * 1024 * 1024) {
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GiB (${bytes} bytes)`;
  }
  if (bytes >= 1024 * 1024) {
    return `${(bytes / (1024 * 1024)).toFixed(2)} MiB (${bytes} bytes)`;
  }
  if (bytes >= 1024) {
    return `${(bytes / 1024).toFixed(2)} KiB (${bytes} bytes)`;
  }
  return `${bytes} bytes`;
}

/**
 * Parse the numeric or "unlimited" output of a single `ulimit -X` call
 * into a KB value.  Returns NOLIMIT for "unlimited".
 */
function parseUlimitKb(raw: string): number {
  const trimmed = raw.trim();
  if (trimmed === 'unlimited') return NOLIMIT;
  const n = parseInt(trimmed, 10);
  return isNaN(n) ? 0 : n;
}

/**
 * Run a single `ulimit -X` flag and return the raw stdout string.
 * Returns an empty string on failure.
 */
function runUlimit(flag: string): string {
  const result = shell.execOutSync('sh', '-c', `ulimit ${flag} 2>&1`);
  if (result.rc !== 0 || !result.out) return '';
  return result.out.trim();
}

/**
 * Scan lines of ESM command output and return the value for a named field.
 *
 * Matches lines containing `<fieldName>=<value>` or `<fieldName>= <value>`.
 * For example, searching for 'SIZE' correctly matches ' SIZE= 2096128' but
 * not ' MAXSIZE= 0'.
 *
 * Returns undefined when the field is not found.
 */
function parseEsmField(output: string, fieldName: string): string | undefined {
  const lines = output.split('\n');
  // Match: optional leading whitespace, exact field name, optional spaces, =, optional spaces, value
  const pattern = new RegExp(`(?:^|\\s)${fieldName}\\s*=\\s*(\\S+)`);
  for (let i = 0; i < lines.length; i++) {
    const match = lines[i].match(pattern);
    if (match) {
      return match[1].trim();
    }
  }
  return undefined;
}

// ─── ESM-specific configuration ───────────────────────────────────────────────

/**
 * Configuration for per-ESM TSO query commands and output field names.
 *
 * Field-name notes:
 *   RACF  : LISTUSER output uses ASSIZEMAX, MEMLIMIT, and SIZE (in TSO section).
 *   TSS   : TSS LIST output uses ASSSIZE (not ASSIZEMAX), MEMLIMIT, SIZE.
 *           Ref: CA Top Secret for z/OS Administration Guide – OMVS segment.
 *   ACF2  : ACFCMD SHOW LID output uses ASSSIZE, MEMLIMIT, SIZE.
 *           If the ACFCMD command is unavailable (common when not configured),
 *           the check is skipped and manual commands are printed.
 *           Ref: Broadcom CA-ACF2 for z/OS – Logonid OMVS Fields.
 */
interface EsmConfig {
  /** TSO command string for OMVS segment query, with %USER% placeholder */
  omvsCmd: string;
  /** TSO command string for TSO segment query, with %USER% placeholder.
   *  Empty string if OMVS and TSO are returned together by omvsCmd. */
  tsoCmd: string;
  /** Field name for address-space size limit in OMVS output */
  assizeField: string;
  /** Field name for above-the-bar memory limit in OMVS output */
  memlimitField: string;
  /** Field name for TSO region size in TSO output */
  tsoSizeField: string;
  /** Human-readable remediation command for address-space limit, with %USER% */
  assizeFixCmd: (user: string, min: string) => string;
  /** Human-readable remediation command for MEMLIMIT, with %USER% */
  memlimitFixCmd: (user: string, min: string) => string;
  /** Human-readable remediation command for TSO SIZE, with %USER% */
  tsoSizeFixCmd: (user: string, min: string) => string;
}

const ESM_CONFIGS: { [esm: string]: EsmConfig } = {
  [ESM_RACF]: {
    omvsCmd:       'LISTUSER %USER% OMVS NORACF',
    tsoCmd:        'LISTUSER %USER% TSO NORACF',
    assizeField:   'ASSIZEMAX',
    memlimitField: 'MEMLIMIT',
    tsoSizeField:  'SIZE',
    assizeFixCmd:  (u, min) => `ALTUSER ${u} OMVS(ASSIZEMAX(${min}))`,
    memlimitFixCmd:(u, min) => `ALTUSER ${u} OMVS(MEMLIMIT(${min}))`,
    tsoSizeFixCmd: (u, min) => `ALTUSER ${u} TSO(SIZE(${min}))`,
  },
  [ESM_TSS]: {
    // TSS LIST(acid) SEGMENT(OMVS) displays the OMVS segment of an ACID.
    // TSS LIST(acid) SEGMENT(TSO) displays the TSO attributes.
    // Field names differ from RACF: ASSSIZE (not ASSIZEMAX).
    omvsCmd:       'TSS LIST(%USER%) SEGMENT(OMVS)',
    tsoCmd:        'TSS LIST(%USER%) SEGMENT(TSO)',
    assizeField:   'ASSSIZE',
    memlimitField: 'MEMLIMIT',
    tsoSizeField:  'SIZE',
    assizeFixCmd:  (u, min) => `TSS ADD(${u}) ASSSIZE(${min})`,
    memlimitFixCmd:(u, min) => `TSS ADD(${u}) MEMLIMIT(${min})`,
    tsoSizeFixCmd: (u, min) => `TSS ADD(${u}) SIZE(${min})`,
  },
  [ESM_ACF2]: {
    // ACF2 OMVS and TSO attributes are stored in the logonid (LID) record.
    // ACFCMD SHOW LID(acid) displays the full logonid record.
    // Field names differ slightly: ASSSIZE is used for address-space size.
    // NOTE: ACFCMD requires the ACF2 TSO command processor to be configured.
    // If this command fails, run manually in an ACF2 batch job (PGM=ACFBATCH):
    //   SET PROFILE(USER) DIV(OMVS)
    //   SHOW LID(userid)
    omvsCmd:       'ACFCMD SHOW LID(%USER%)',
    tsoCmd:        '',   // TSO attributes are included in the LID record
    assizeField:   'ASSSIZE',
    memlimitField: 'MEMLIMIT',
    tsoSizeField:  'SIZE',
    assizeFixCmd:  (u, min) =>
      `(ACF2 batch) SET PROFILE(USER) DIV(OMVS) / CHANGE LID(${u}) ASSSIZE(${min})`,
    memlimitFixCmd:(u, min) =>
      `(ACF2 batch) SET PROFILE(USER) DIV(OMVS) / CHANGE LID(${u}) MEMLIMIT(${min})`,
    tsoSizeFixCmd: (u, min) =>
      `(ACF2 batch) SET LID / CHANGE LID(${u}) SIZE(${min})`,
  },
};

// ─── Result record ────────────────────────────────────────────────────────────

interface MemoryCheckResult {
  label: string;
  displayValue: string;       // human-readable current value
  displayMinimum: string;     // human-readable minimum
  passed: boolean;
  informational: boolean;     // true → report but do not count as failure
  note: string;
}

// ─────────────────────────────────────────────────────────────────────────────

/**
 * Validate memory constraints for a z/OS user and/or the running process.
 *
 * @param userId            User ID to query via RACF LISTUSER.  Defaults to
 *                          the current user when omitted or empty.
 * @param minAssizemaxRaw   RACF OMVS ASSIZEMAX minimum as a string.
 *                          May be a byte count or "NOLIMIT" (require unlimited).
 *                          Defaults to "2147483647".
 * @param minUlimitAKb      Minimum ulimit -A value in KB.
 *                          Defaults to 250000.
 * @param minTsoSize        Minimum RACF TSO SIZE (units of 1 KB).
 *                          Defaults to 2096128.
 * @param minMemlimitStr    Minimum RACF OMVS MEMLIMIT as a size string,
 *                          e.g. "4G" or "512M".  Defaults to "4G".
 *
 * @returns Number of failed (non-informational) checks.  0 means success.
 */
export function execute(
  userId?: string,
  minAssizemaxRaw?: string,
  minUlimitAKb?: number,
  minTsoSize?: number,
  minMemlimitStr?: string,
): number {
  // ── Resolve effective user ID ─────────────────────────────────────────────
  const effectiveUser = (userId && userId.trim().length > 0)
    ? userId.trim().toUpperCase()
    : (common.getUserId() || 'CURRENT').toUpperCase();

  // ── Resolve effective minimums ────────────────────────────────────────────
  const requireNolimitAssizemax = minAssizemaxRaw &&
    minAssizemaxRaw.trim().toUpperCase() === 'NOLIMIT';
  const minAssizemaxBytes: number = requireNolimitAssizemax
    ? NOLIMIT
    : (minAssizemaxRaw ? (parseInt(minAssizemaxRaw, 10) || DEFAULT_MIN_ASSIZEMAX_BYTES)
                       : DEFAULT_MIN_ASSIZEMAX_BYTES);

  const minUlimit = (minUlimitAKb !== undefined && !isNaN(minUlimitAKb))
    ? minUlimitAKb
    : DEFAULT_MIN_ULIMIT_A_KB;

  const minTso = (minTsoSize !== undefined && !isNaN(minTsoSize))
    ? minTsoSize
    : DEFAULT_MIN_TSO_SIZE;

  const effectiveMinMemlimitStr = (minMemlimitStr && minMemlimitStr.trim().length > 0)
    ? minMemlimitStr.trim()
    : DEFAULT_MIN_MEMLIMIT_STR;
  const minMemlimitBytes = parseMemorySize(effectiveMinMemlimitStr);

  // ── Collection of check results ───────────────────────────────────────────
  const results: MemoryCheckResult[] = [];

  // ─────────────────────────────────────────────────────────────────────────
  // Section 1: Current-process ulimit checks
  // These reflect the actual OS limits imposed on whatever process is running
  // zwe (typically the Zowe service account).
  // ─────────────────────────────────────────────────────────────────────────
  common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME,
    `Checking current-process ulimit values`);

  // ulimit -A : address space size (KB) – hard Zowe requirement
  const ulimitARaw = runUlimit('-A');
  const ulimitAKb  = ulimitARaw ? parseUlimitKb(ulimitARaw) : 0;
  const ulimitAPassed = ulimitAKb === NOLIMIT || ulimitAKb >= minUlimit;
  results.push({
    label:        'ulimit -A  (address space size, kbytes)',
    displayValue: ulimitARaw || 'unknown',
    displayMinimum: minUlimit.toString(),
    passed:       ulimitAPassed,
    informational: false,
    note: 'Current-process address space limit. ' +
          `Zowe requires at least ${minUlimit} KB. ` +
          'Set via OMVS ASSIZEMAX in the user\'s RACF profile, or ulimit -A in shell.'
  });

  // ulimit -d : data segment (KB) – informational
  const ulimitDRaw = runUlimit('-d');
  results.push({
    label:        'ulimit -d  (data segment size, kbytes)',
    displayValue: ulimitDRaw || 'unknown',
    displayMinimum: 'N/A (informational)',
    passed:       true,
    informational: true,
    note: 'Unlimited is recommended for Zowe.'
  });

  // ulimit -s : stack size (KB) – informational
  const ulimitSRaw = runUlimit('-s');
  results.push({
    label:        'ulimit -s  (stack size, kbytes)',
    displayValue: ulimitSRaw || 'unknown',
    displayMinimum: 'N/A (informational)',
    passed:       true,
    informational: true,
    note: 'Default z/OS stack size is usually adequate for Zowe.'
  });

  // ulimit -v : virtual memory (KB) – informational
  const ulimitVRaw = runUlimit('-v');
  results.push({
    label:        'ulimit -v  (virtual memory, kbytes)',
    displayValue: ulimitVRaw || 'unknown',
    displayMinimum: 'N/A (informational)',
    passed:       true,
    informational: true,
    note: 'Unlimited is recommended. A low ceiling may prevent Java JVM startup.'
  });

  // ulimit -m : max RSS (KB) – informational
  const ulimitMRaw = runUlimit('-m');
  results.push({
    label:        'ulimit -m  (max RSS / resident set, kbytes)',
    displayValue: ulimitMRaw || 'unknown',
    displayMinimum: 'N/A (informational)',
    passed:       true,
    informational: true,
    note: 'Unlimited is recommended.'
  });

  // ── Detect ESM ────────────────────────────────────────────────────────────
  const esm: string = zosNative.getEsm() || 'NONE';
  const esmConfig: EsmConfig | undefined = ESM_CONFIGS[esm];

  common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME,
    `Detected External Security Manager (ESM): ${esm}`);

  if (!esmConfig) {
    common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME,
      `ZWEL0375W: ESM type '${esm}' is not recognized (expected RACF, TSS, or ACF2). ` +
      `ESM-based memory constraint checks (OMVS ASSIZEMAX, MEMLIMIT, TSO SIZE) will be skipped.`);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 2: ESM OMVS segment checks for the target user
  // ─────────────────────────────────────────────────────────────────────────
  if (esmConfig) {
    const omvsCmd = esmConfig.omvsCmd.replace('%USER%', effectiveUser);
    common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME,
      `Querying ${esm} OMVS segment for user ${effectiveUser}: ${omvsCmd}`);

    const omvsResult = zos.tsoCommand(...omvsCmd.split(' '));

    if (omvsResult.rc === 0 && omvsResult.out) {

      // OMVS address-space size ──────────────────────────────────────────────
      const assizemaxStr = parseEsmField(omvsResult.out, esmConfig.assizeField);
      if (assizemaxStr !== undefined) {
        const assizemaxIsNolimit = assizemaxStr.toUpperCase() === 'NOLIMIT'
                                || assizemaxStr.toUpperCase() === 'NONE'
                                || assizemaxStr === '0';
        const assizemaxVal: number = assizemaxIsNolimit
          ? NOLIMIT
          : (parseInt(assizemaxStr, 10) || 0);

        let assizemaxPassed: boolean;
        let minDisplay: string;

        if (requireNolimitAssizemax) {
          assizemaxPassed = assizemaxIsNolimit;
          minDisplay = 'NOLIMIT (required)';
        } else {
          assizemaxPassed = assizemaxVal === NOLIMIT || assizemaxVal >= minAssizemaxBytes;
          minDisplay = formatBytes(minAssizemaxBytes);
        }

        results.push({
          label:        `${esm} OMVS ${esmConfig.assizeField} for ${effectiveUser} (bytes)`,
          displayValue: assizemaxIsNolimit
            ? 'NOLIMIT (unlimited)'
            : formatBytes(assizemaxVal),
          displayMinimum: minDisplay,
          passed:       assizemaxPassed,
          informational: false,
          note: `${esm} per-user address-space maximum. ` +
                `Zowe documentation recommends ${DEFAULT_MIN_ASSIZEMAX_BYTES} bytes or unlimited. ` +
                `Set with: ${esmConfig.assizeFixCmd(effectiveUser, DEFAULT_MIN_ASSIZEMAX_BYTES.toString())}`
        });
      } else {
        common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME,
          `ZWEL0374W: ${esmConfig.assizeField} not found in ${esm} OMVS output for ` +
          `user ${effectiveUser}. The field may not be configured.`);
      }

      // OMVS MEMLIMIT ────────────────────────────────────────────────────────
      const memlimitStr = parseEsmField(omvsResult.out, esmConfig.memlimitField);
      if (memlimitStr !== undefined) {
        const memlimitBytes = parseMemorySize(memlimitStr);
        const memlimitPassed = memlimitBytes === NOLIMIT || memlimitBytes >= minMemlimitBytes;
        results.push({
          label:        `${esm} OMVS ${esmConfig.memlimitField} for ${effectiveUser}`,
          displayValue: memlimitStr,
          displayMinimum: effectiveMinMemlimitStr,
          passed:       memlimitPassed,
          informational: false,
          note: `64-bit (above-the-bar) memory limit. ` +
                `Required for Java and 64-bit address space usage by Zowe. ` +
                `Set with: ${esmConfig.memlimitFixCmd(effectiveUser, effectiveMinMemlimitStr)}`
        });
      } else {
        common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME,
          `ZWEL0374W: ${esmConfig.memlimitField} not found in ${esm} OMVS output for ` +
          `user ${effectiveUser}.`);
      }

      // Additional informational fields depending on ESM ────────────────────
      if (esm === ESM_RACF) {
        const cputimeStr = parseEsmField(omvsResult.out, 'CPUTIMEMAX');
        if (cputimeStr !== undefined) {
          results.push({
            label:        `RACF OMVS CPUTIMEMAX for ${effectiveUser}`,
            displayValue: cputimeStr,
            displayMinimum: 'N/A (informational)',
            passed:       true,
            informational: true,
            note: 'CPU time limit per process. NONE means unlimited.'
          });
        }
        const procuserStr = parseEsmField(omvsResult.out, 'PROCUSERMAX');
        if (procuserStr !== undefined) {
          results.push({
            label:        `RACF OMVS PROCUSERMAX for ${effectiveUser}`,
            displayValue: procuserStr,
            displayMinimum: 'N/A (informational)',
            passed:       true,
            informational: true,
            note: 'Maximum number of concurrent processes. NONE means unlimited.'
          });
        }
      }

    } else {
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME,
        `ZWEL0371W: Could not retrieve ${esm} OMVS segment for user ${effectiveUser}. ` +
        `Insufficient privileges, user not found, or ${esm} is not active. ` +
        (esm === ESM_ACF2
          ? `For ACF2, run manually in a batch job (PGM=ACFBATCH): SET PROFILE(USER) DIV(OMVS) / SHOW LID(${effectiveUser}). `
          : '') +
        `OMVS constraint checks are skipped.`);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 3: ESM TSO segment checks for the target user
  // ─────────────────────────────────────────────────────────────────────────
  if (esmConfig) {
    // ACF2 returns TSO attributes as part of the LID record (same query as OMVS).
    // We re-query with omvsCmd for ACF2; for RACF and TSS we use the dedicated tsoCmd.
    const tsoQueryCmd = (esm === ESM_ACF2 || !esmConfig.tsoCmd)
      ? esmConfig.omvsCmd.replace('%USER%', effectiveUser)
      : esmConfig.tsoCmd.replace('%USER%', effectiveUser);

    common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME,
      `Querying ${esm} TSO segment for user ${effectiveUser}: ${tsoQueryCmd}`);

    const tsoResult = (esm === ESM_ACF2 || !esmConfig.tsoCmd)
      ? zos.tsoCommand(...esmConfig.omvsCmd.replace('%USER%', effectiveUser).split(' '))
      : zos.tsoCommand(...esmConfig.tsoCmd.replace('%USER%', effectiveUser).split(' '));

    if (tsoResult.rc === 0 && tsoResult.out) {

      // TSO region SIZE ──────────────────────────────────────────────────────
      const tsoSizeStr = parseEsmField(tsoResult.out, esmConfig.tsoSizeField);
      if (tsoSizeStr !== undefined) {
        const tsoSizeVal = parseInt(tsoSizeStr, 10) || 0;
        const tsoSizePassed = tsoSizeVal >= minTso;
        results.push({
          label:        `${esm} TSO ${esmConfig.tsoSizeField} for ${effectiveUser} (kbytes)`,
          displayValue: `${tsoSizeVal} KB`,
          displayMinimum: `${minTso} KB`,
          passed:       tsoSizePassed,
          informational: false,
          note: `TSO address-space region size in 1-KB units. ` +
                `Zowe documentation recommends ${DEFAULT_MIN_TSO_SIZE} KB. ` +
                `Set with: ${esmConfig.tsoSizeFixCmd(effectiveUser, DEFAULT_MIN_TSO_SIZE.toString())}`
        });
      } else {
        common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME,
          `ZWEL0374W: ${esmConfig.tsoSizeField} not found in ${esm} TSO output for ` +
          `user ${effectiveUser}.`);
      }

      // TSO MAXSIZE – informational only ─────────────────────────────────────
      const tsoMaxsizeStr = parseEsmField(tsoResult.out, 'MAXSIZE');
      if (tsoMaxsizeStr !== undefined) {
        results.push({
          label:        `${esm} TSO MAXSIZE for ${effectiveUser} (kbytes)`,
          displayValue: `${tsoMaxsizeStr} KB`,
          displayMinimum: 'N/A (informational)',
          passed:       true,
          informational: true,
          note: 'Maximum SIZE a user is allowed to specify at TSO logon. 0 means no limit.'
        });
      }

    } else {
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME,
        `ZWEL0372W: Could not retrieve ${esm} TSO segment for user ${effectiveUser}. ` +
        `Insufficient privileges, user not found, TSO segment not defined, ` +
        `or ${esm} is not active. TSO constraint checks are skipped.`);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Print results table
  // ─────────────────────────────────────────────────────────────────────────
  common.printMessage('');
  common.printLevel1Message(`Memory constraint validation results for user: ${effectiveUser} (ESM: ${esm})`);

  let failedCount = 0;

  for (let i = 0; i < results.length; i++) {
    const r = results[i];
    const tag = r.informational ? 'INFO' : (r.passed ? 'PASS' : 'FAIL');
    common.printMessage(`  [${tag}] ${r.label}`);
    common.printMessage(`         Value   : ${r.displayValue}`);
    common.printMessage(`         Minimum : ${r.displayMinimum}`);
    common.printMessage(`         Note    : ${r.note}`);
    common.printMessage('');

    if (!r.passed && !r.informational) {
      failedCount++;
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME,
        `ZWEL0370E: Memory constraint '${r.label}' for user ${effectiveUser} ` +
        `has value '${r.displayValue}', which is below the required minimum of '${r.displayMinimum}'.`);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Summary
  // ─────────────────────────────────────────────────────────────────────────
  if (failedCount === 0) {
    common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME,
      `Memory constraint validation passed for user ${effectiveUser}.`);
  } else {
    common.printFormattedError(common.MSG_KEY, COMMAND_NAME,
      `ZWEL0373E: ${failedCount} memory constraint validation(s) failed ` +
      `for user ${effectiveUser}. Review the output above for corrective actions.`);
  }

  return failedCount;
}
