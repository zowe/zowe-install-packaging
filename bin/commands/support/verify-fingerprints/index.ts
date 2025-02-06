/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as xplatform from 'xplatform';

import * as common from '../../../libs/common';
import * as fs from '../../../libs/fs';
import * as javaCI from '../../../libs/java_ci';
import * as shell from '../../../libs/shell';
import * as stringlib from '../../../libs/string';

// Originally in shell: "echo $result | head -n 10 | awk '{ print $1 }')"
function processCommResult(content: string, lines?: number): string {
  let returnedOutput = '';
  if (content) {
    let linesSplit = content.split("\n");
    // head -n lines
    if (lines && lines > 0) {
      linesSplit = linesSplit.slice(0, lines);
    }
    // awk '{ print $1 }'
    linesSplit.forEach(line => {
      const oneLineSplit = line.split(' ');
      returnedOutput += `${oneLineSplit[0]}\n`
    })
  }
  return returnedOutput;
}

export function execute(doNotExit: Boolean, javaHome: string): void {

  common.printLevel0Message('Verify Zowe file fingerprints');

  if (!javaHome) {
    javaHome = std.getenv('JAVA_HOME');
    const validJava = javaCI.validateJavaHome(javaHome);
    if (!validJava) {
      common.printErrorAndExit('Error ZWEL0122E Cannot find java. Please define JAVA_HOME environment variable.', undefined, 122);
    }
  }

  const tmpFilePrefix = 'zwe-support-verify-fingerprints';
  const zoweRuntime = std.getenv('ZWE_zowe_runtimeDirectory');
  const manifest = `${zoweRuntime}/manifest.json`

  let manifestContent = undefined;
  let manifestJson = undefined;
  if (fs.fileExists(manifest)) {
      manifestContent = xplatform.loadFileUTF8(manifest, xplatform.AUTO_DETECT);
  } else {
      common.printErrorAndExit(`Error ZWEL0150E: Failed to find file "${manifest}". Zowe runtimeDirectory is invalid.`, undefined, 150);
  }
  if (manifestContent) {
      manifestJson = JSON.parse(manifestContent);
  }
  if (!manifestContent || !manifestJson.version) {
      common.printErrorAndExit("Error ZWEL0113E: Failed to find Zowe version. Please validate your Zowe directory.", undefined, 113);
  }
  const zoweVersion = manifestJson.version;

  if (!fs.fileExists(`${zoweRuntime}/bin/utils/HashFiles.class`)) {
      common.printErrorAndExit(`Error ZWEL0150E: Failed to find file "${zoweRuntime}/bin/utils/HashFiles.class". Zowe runtimeDirectory is invalid.`, undefined, 150);
  }

  if (!fs.fileExists(`${zoweRuntime}/fingerprint/RefRuntimeHash-${zoweVersion}.txt`)) {
      common.printErrorAndExit(`Error ZWEL0150E: Failed to find file "${zoweRuntime}/fingerprint/RefRuntimeHash-${zoweVersion}.txt". Zowe runtimeDirectory is invalid.`, undefined, 150);
  }

  common.printMessage('- Create Zowe directory file list');
  const allFiles = fs.createTmpFile(tmpFilePrefix);
  shell.execOutSync('sh', '-c', `cd '${zoweRuntime}' && find . -name ./SMPE -prune -o -name "./ZWE*" -prune -o -name ./fingerprint -prune -o -type f -print > "${allFiles}"`);
  if (!fs.fileExists(allFiles)) {
    common.printErrorAndExit(`Error ZWEL0151E: Failed to create temporary file "${allFiles}". Please check permission or volume free space.`, undefined, 151);
  }

  common.printDebug(`  * File list created as ${allFiles}`);
  shell.execSync('sh', '-c', `chmod 700 "${allFiles}"`);

  common.printMessage('- Calculate hashes of Zowe files');

  const customHashes = fs.createTmpFile(tmpFilePrefix);
  const javaHash = shell.execOutSync('sh', '-c', `cd '${zoweRuntime}' && '${javaHome}/bin/java' -cp '${zoweRuntime}/bin/utils/' HashFiles '${allFiles}' | sort > '${customHashes}'`);

  if (javaHash.rc != 0 || !fs.fileExists(customHashes) || fs.fileSize(customHashes) < 1) {
    common.printError(`  * Error ZWEL0151E: Failed to create temporary file ${customHashes}. Please check permission or volume free space.`);
    common.printError(`  * Exit code: java error code=${javaHash.rc}`)
    common.printError(`  *            file exists=${fs.fileExists(customHashes)}`);
    if (fs.fileExists(customHashes)) {
      common.printError(`  *            file size=${fs.fileSize(customHashes)}`);
      fs.rmrf(allFiles);
      fs.rmrf(customHashes);
    }
    if (javaHash.out) {
      common.printError(stringlib.paddingLeft(javaHash.out, "    "));
    }
    std.exit(151);
  }

  common.printDebug(`  * Zowe file hashes created as ${customHashes}`);
  shell.execSync('sh', '-c', `chmod 700 "${customHashes}"`);

  let verifyFailed = false;
  const logLevel = std.getenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS');
  const COMM = [
    [ 3, 'different' ],
    [ 13, 'extra' ],
    [ 23, 'missing' ]
  ]

  COMM.forEach(commSetting => {
    const commParameter = commSetting[0];
    const commStepName = commSetting[1]
    common.printMessage(`- Find ${commStepName} files`);
    const commResult = shell.execOutSync('sh', '-c', `cd '${zoweRuntime}' && comm -${commParameter} "${zoweRuntime}/fingerprint/RefRuntimeHash-${zoweVersion}.txt" "${customHashes}"`);
    if (commResult.rc) {
      common.printError(`  * Error ZWEL0151E: Failed to compare hashes of fingerprint/RefRuntimeHash-${zoweVersion}.txt and current.`);
      common.printError(`  * Exit code: ${commResult.rc}`);
      if (commResult.out) {
        common.printError(`  * Output:`);
        common.printError(`${stringlib.paddingLeft(commResult.out, "    ")}`);
      }
      fs.rmrf(allFiles);
      fs.rmrf(customHashes);
      std.exit(151);
    }

    if (commResult.out) {
      const linesReturned =  commResult.out.split("\n").length;
      common.printMessage(`  * Number of ${commStepName} files: ${linesReturned}`);
      if (linesReturned) {
        verifyFailed = true;
        if (logLevel == 'TRACE' ) {
          common.printTrace(`  * All ${commStepName} files:`);
          common.printTrace(processCommResult(commResult.out, undefined));
        }
        if (logLevel == 'DEBUG') {
          common.printDebug(`  * First 10 ${commStepName} files:`);
          common.printDebug(stringlib.paddingLeft(processCommResult(commResult.out, 10),"    "));
        }
      }
    } else {
      common.printMessage(`   * Number of ${commStepName} files: 0`);
    }
  });

  fs.rmrf(allFiles);
  fs.rmrf(customHashes);

  if (verifyFailed) {
    common.printMessage("");
    common.printError('Error ZWEL0181E: Failed to verify Zowe file fingerprints.');
    if (doNotExit != true) {
      std.exit(181);
    }
  } else {
    common.printLevel1Message('Zowe file fingerprints verification passed.');
  }
}
