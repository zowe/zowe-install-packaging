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
import * as shell from '../../../libs/shell';
import * as stringlib from '../../../libs/string';

// This function is a copy of existing ../../../libs/java(validateJavaHome)
// The reason for such terrible approach is, this command could run standalone
// without config: zwe support verify-fingerprints (no parms)
// By importing java we will force to use a config.
// Either:
//   * Copy of a function and backward compatibility
//   * Import of a function and braking change (config required)

const JAVA_MIN_VERSION = 17;

export function validateJavaHome(javaHome:string|undefined=std.getenv("JAVA_HOME")): boolean {
  if (!javaHome) {
    common.printError("Cannot find java. Please define JAVA_HOME environment variable.");
    return false;
  }
  if (!fs.fileExists(fs.resolvePath(javaHome,`/bin/java`))) {
    common.printError(`JAVA_HOME: ${javaHome}/bin does not point to a valid install of Java.`);
    return false;
  }

  let execReturn = shell.execErrSync(fs.resolvePath(javaHome,`/bin/java`), `-version`);
  const version = execReturn.err;
  if (execReturn.rc != 0) {
    common.printError(`Java version check failed with return code: ${execReturn.rc}: ${version}`);
    return false;
  }

  try {
    let index = 0;
    let javaVersionShort;
    let versionLines = (version as string).split('\n'); // valid because of above rc check
    for (let i = 0; i < versionLines.length; i++) {
      if ((index = versionLines[i].indexOf('java version')) != -1) {
        //format of: java version "1.8.0_321" OR java version "17.0.10" 2024-01-02
        javaVersionShort = versionLines[i].substring(index+('java version'.length)+2);
        javaVersionShort = javaVersionShort.replace(/"/g, '');
        break;
      } else if ((index = versionLines[i].indexOf('openjdk version')) != -1) {
        javaVersionShort=versionLines[i].substring(index+('openjdk version'.length)+2, versionLines[i].length-1);
        break;
      }
    }
    if (!javaVersionShort){
      common.printError("could not find java version");
      return false;
    }
    let versionParts = javaVersionShort.split('.');
    const javaMajorVersion=Number(versionParts[0]);
    const javaMinorVersion=Number(versionParts[1]);

    let tooLow=false;
    if (javaMajorVersion !== 1 && javaMajorVersion < JAVA_MIN_VERSION) {
      tooLow=true;
    }
    if (javaMajorVersion === 1 && javaMinorVersion < JAVA_MIN_VERSION) {
      tooLow=true;
    }

    if (tooLow) {
      common.printError(`Java ${javaVersionShort} is less than the minimum level required of Java ${JAVA_MIN_VERSION}.`);
      return false;
    }

    common.printDebug(`Java ${javaVersionShort} is supported.`);
    common.printDebug(`Java check is successful.`);
    return true;
  } catch (e) {
    return false;
  }
}

function processCommResult(content: string, lines?: number): string {
  let returnedOutput = '';
  if (content) {
    let linesSplit = content.split("\n");
    if (lines && lines > 0) {
      linesSplit = linesSplit.slice(0, lines);
    }
    linesSplit.forEach(line => {
      const oneLineSplit = line.split(' ');
      returnedOutput += `${oneLineSplit[0]}\n`
    })
  }
  return returnedOutput;
}

export function execute(doNotExit: Boolean): void {

  common.printLevel0Message('Verify Zowe file fingerprints');

  const validJava = validateJavaHome(std.getenv('JAVA_HOME'));
  if (!validJava) {
    common.printErrorAndExit('Error ZWEL0122E Cannot find java. Please define JAVA_HOME environment variable.', undefined, 122);
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
  const javaHash = shell.execOutSync('sh', '-c', `cd '${zoweRuntime}' && java -cp "${zoweRuntime}/bin/utils/" HashFiles "${allFiles}" | sort > "${customHashes}"`);

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
