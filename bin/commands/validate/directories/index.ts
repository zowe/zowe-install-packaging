/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as fs from '../../../libs/fs';

const COMMAND_NAME = 'zwe-validate-directories';

type DirEntry = { yamlPath: string; value: string; normalized: string };

/** Strip trailing slashes for consistent prefix comparisons. */
function normalize(p: string): string {
  return p.replace(/\/+$/, '');
}

/**
 * Checks that:
 *  - No two of the four Zowe directories share the same path.
 *  - None of the four Zowe directories resides within any other.
 *  - None of the instance directories (workspace, log, extension) are
 *     globally (world) writable.
 *  - All instance directories are readable by the user running this command.
 *
 * @param quitOnError  When true, exits the process on failure (default: false).
 * @returns 0 on success or the number of Errors found.
 */
export function execute(quitOnError?: boolean): number {
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();

  const runtimeDirectory: string | undefined = ZOWE_CONFIG?.zowe?.runtimeDirectory;

  if (!runtimeDirectory) {
    common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `zowe.runtimeDirectory is not set; skipping directory validation.`);
    return 0;
  }

  const allDirectoryDefs: { [yamlPath: string]: string | undefined } = {
    'zowe.runtimeDirectory':   runtimeDirectory,
    'zowe.workspaceDirectory': ZOWE_CONFIG?.zowe?.workspaceDirectory,
    'zowe.logDirectory':       ZOWE_CONFIG?.zowe?.logDirectory,
    'zowe.extensionDirectory': ZOWE_CONFIG?.zowe?.extensionDirectory,
  };

  const instanceDirectoryDefs: { [yamlPath: string]: string | undefined } = {
    'zowe.workspaceDirectory': ZOWE_CONFIG?.zowe?.workspaceDirectory,
    'zowe.logDirectory':       ZOWE_CONFIG?.zowe?.logDirectory,
    'zowe.extensionDirectory': ZOWE_CONFIG?.zowe?.extensionDirectory,
  };

  // Build a flat list of set entries for pair-wise comparisons.
  const allEntries: DirEntry[] = [];
  for (const [yamlPath, dirValue] of Object.entries(allDirectoryDefs)) {
    if (dirValue) {
      allEntries.push({ yamlPath, value: dirValue, normalized: normalize(dirValue) });
    } else {
      common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME, `${yamlPath} is not set; skipping.`);
    }
  }

  let totalErrors = 0;

  // Directories should not be equal
  const equalityErrors: { a: DirEntry; b: DirEntry }[] = [];
  for (let i = 0; i < allEntries.length; i++) {
    for (let j = i + 1; j < allEntries.length; j++) {
      if (allEntries[i].normalized === allEntries[j].normalized) {
        equalityErrors.push({ a: allEntries[i], b: allEntries[j] });
      }
    }
  }

  if (equalityErrors.length > 0) {
    const lines = equalityErrors
      .map(v => `  ${v.a.yamlPath} (${v.a.value}) and ${v.b.yamlPath} (${v.b.value})`)
      .join('\n');
    common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `ZWEL0363E: The following Zowe directories share the same path, which is not allowed:\n${lines}`);
    totalErrors += equalityErrors.length;
  }

  // Directories should not be within each other
  const nestingErrors: { child: DirEntry; parent: DirEntry }[] = [];
  for (let i = 0; i < allEntries.length; i++) {
    for (let j = 0; j < allEntries.length; j++) {
      if (i === j) continue;
      const candidate = allEntries[i];
      const parent    = allEntries[j];
      if (candidate.normalized.startsWith(parent.normalized + '/')) {
        nestingErrors.push({ child: candidate, parent });
      }
    }
  }

  if (nestingErrors.length > 0) {
    const lines = nestingErrors
      .map(v => `  ${v.child.yamlPath} (${v.child.value}) resides within ${v.parent.yamlPath} (${v.parent.value})`)
      .join('\n');
    common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `ZWEL0364E: The following Zowe directories reside within another Zowe directory, which is not allowed:\n${lines}`);
    totalErrors += nestingErrors.length;
  }

  // Check permissions
  const worldWritableErrors: { yamlPath: string; value: string }[] = [];
  const notReadableErrors:   { yamlPath: string; value: string }[] = [];

  for (const [yamlPath, dirValue] of Object.entries(instanceDirectoryDefs)) {
    if (!dirValue) {
      continue;
    }

    common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME, `Checking permissions for ${yamlPath}: ${dirValue}`);

    if (fs.hasWorldPermissions(dirValue, undefined, true)) {
      worldWritableErrors.push({ yamlPath, value: dirValue });
    }

    if (!fs.isDirectoryAccessible(dirValue)) {
      notReadableErrors.push({ yamlPath, value: dirValue });
    }
  }

  if (worldWritableErrors.length > 0) {
    const lines = worldWritableErrors.map(v => `  ${v.yamlPath}: ${v.value}`).join('\n');
    common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `ZWEL0361E: The following instance directories are globally (world) writable, which is a security risk:\n${lines}`);
    totalErrors += worldWritableErrors.length;
  }

  if (notReadableErrors.length > 0) {
    const lines = notReadableErrors.map(v => `  ${v.yamlPath}: ${v.value}`).join('\n');
    common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `ZWEL0362E: The following instance directories are not readable by the current user:\n${lines}`);
    totalErrors += notReadableErrors.length;
  }

  if (totalErrors === 0) {
    common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `Zowe directory validation passed.`);
    return 0;
  }

  const summaryMsg = `ZWEL0360E: ${totalErrors} directory validation(s) failed. This check can be dismissed with YAML value "zowe.launchScript.startupChecks.directories: warn"`;

  if (!quitOnError) {
    common.printFormattedError(common.MSG_KEY, COMMAND_NAME, summaryMsg);
  } else {
    common.printErrorAndExit(summaryMsg, undefined, 8);
  }

  return totalErrors;
}
