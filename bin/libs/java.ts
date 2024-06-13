/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as os from 'cm_os';
import * as fs from './fs';
import * as common from './common';
import * as shell from './shell';
import * as config from './config';

const JAVA_MIN_VERSION=8;

export function ensureJavaIsOnPath(): void {
  let path=std.getenv('PATH') || '/bin:.:/usr/bin';
  let javaHome=std.getenv('JAVA_HOME');
  if (!path.includes(`:${javaHome}/bin:`)) {
    std.setenv('PATH', `${javaHome}/bin:${path}`);
  }
}

export function shellReadYamlJavaHome(configList?: string, skipValidate?: boolean): string {
  const zoweConfig = config.getZoweConfig();
  if (zoweConfig && zoweConfig.java && zoweConfig.java.home) {
    if (!skipValidate) {
      if (!validateJavaHome(zoweConfig.java.home)) {
        return '';
      }
    }
    return zoweConfig.java.home;
  }
  return '';
}

export function detectJavaHome(): string|undefined {
  let javaBinHome = shell.which(`java`);
  if (javaBinHome) {
    let returnVal = os.realpath(`${javaBinHome}/../..`);
    if (!returnVal[1]) {
      return returnVal[0];
    }
  }

  if (!javaBinHome && fs.fileExists('/usr/lpp/java/J8.0_64/bin/java')) {
    return '/usr/lpp/java/J8.0_64';
  }
  return undefined;
}

let _javaCheckComplete = false;
export function requireJava() {
  if ((_javaCheckComplete === true) && std.getenv('JAVA_HOME')) {
    return;
  }
  if (std.getenv('ZWE_CLI_PARAMETER_CONFIG')) {
    const customJavaHome = shellReadYamlJavaHome();
    if (customJavaHome) {
      std.setenv('JAVA_HOME', customJavaHome);
    }
  }
  if (!std.getenv('JAVA_HOME')) {
    let detectedHome = detectJavaHome();
    if (detectedHome){
      std.setenv('JAVA_HOME', detectedHome);
    } 
  }
  if (!std.getenv('JAVA_HOME')) {
    common.printErrorAndExit("Error ZWEL0122E: Cannot find java. Please define JAVA_HOME environment variable.", undefined, 122);
  }

  ensureJavaIsOnPath();
  _javaCheckComplete = true;
}

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
        //format of: java version "1.8.0_321"
        javaVersionShort=versionLines[i].substring(index+('java version'.length)+2, versionLines[i].length-1);
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

export function getJavaPkcs12KeystoreFlag(javaHome:string|undefined=std.getenv("JAVA_HOME")): string {
  if (!javaHome) {
    common.printError("Cannot find java. Please define JAVA_HOME environment variable.");
    return ' ';
  }
  if (!fs.fileExists(fs.resolvePath(javaHome,`/bin/java`))) {
    common.printError(`JAVA_HOME: ${javaHome}/bin does not point to a valid install of Java.`);
    return ' ';
  }

  let execReturn = shell.execErrSync(fs.resolvePath(javaHome,`/bin/java`), `-version`);
  const version = execReturn.err;
  if (execReturn.rc != 0) {
    common.printError(`Java version check failed with return code: ${execReturn.rc}: ${version}`);
    return ' ';
  }
 
  try {
    let index = 0;
    let javaVersionShort;
    let versionLines = (version as string).split('\n'); // valid because of above rc check
    for (let i = 0; i < versionLines.length; i++) {
      if ((index = versionLines[i].indexOf('java version')) != -1) {
        //format of: java version "1.8.0_321"
        javaVersionShort=versionLines[i].substring(index+('java version'.length)+2, versionLines[i].length-1);
        break;
      } else if ((index = versionLines[i].indexOf('openjdk version')) != -1) {
        javaVersionShort=versionLines[i].substring(index+('openjdk version'.length)+2, versionLines[i].length-1);
        break;
      }
    }
    if (!javaVersionShort){
      common.printError("could not find java version");
      return ' ';
    }
    let versionParts = javaVersionShort.split('.');
    const javaMajorVersion=Number(versionParts[0]);
    const javaMinorVersion=Number(versionParts[1]);
    let fixParts = javaVersionShort.split('_');
    const javaFixVersion=Number(fixParts[1]);

    if (javaMajorVersion == 1 && javaMinorVersion == 8) {
      if (javaFixVersion < 341) {
        return ' ';
      } else if (javaFixVersion < 361) {
        return " -J-Dkeystore.pkcs12.certProtectionAlgorithm=PBEWithSHAAnd40BitRC2 -J-Dkeystore.pkcs12.certPbeIterationCount=50000 -J-Dkeystore.pkcs12.keyProtectionAlgorithm=PBEWithSHAAnd3KeyTripleDES -J-Dkeystore.pkcs12.keyPbeIterationCount=50000 "
      } else {
        return " -J-Dkeystore.pkcs12.legacy ";
      }
    } else if (javaMajorVersion == 1 && javaMinorVersion > 8) {
      return " -J-Dkeystore.pkcs12.legacy ";
    } else {
      return ' ';
    }

  } catch (e) {
    return ' ';
  }
}
