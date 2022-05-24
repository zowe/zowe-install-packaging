/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

// @ts-ignore
import * as std from 'std';
// @ts-ignore
import * as os from 'os';
// @ts-ignore
import * as fs from './fs';
import * as common from './common';
import * as shell from './shell';
import * as config from './config';

const JAVA_MIN_VERSION=8;

export function ensureJavaIsOnPath(): void {
  let path=std.getenv('PATH');
  let javaHome=std.getenv('JAVA_HOME');
  if (!path.includes(`:${javaHome}/bin:`)) {
    std.setenv('PATH', `${javaHome}/bin:${path}`);
  }
}

export function shellReadYamlJavaHome(configList?: string, skipValidate?: boolean): string {
  const zoweConfig = config.getZoweConfig();
  if (zoweConfig && zoweConfig.java && zoweConfig.java.home) {
    if (!skipValidate) {
      if (validateJavaHome(zoweConfig.java.home)) {
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
    let returnVal = std.realpath(`${javaBinHome}/../..`);
    if (!returnVal[1]) {
      return returnVal[0];
    }
  }

  if (!javaBinHome && fs.fileExists('/usr/lpp/java/J8.0_64/bin/java')) {
    return '/usr/lpp/java/J8.0_64';
  }
  return undefined;
}

export function requireJava() {
  if (std.getenv('ZWE_CLI_PARAMETER_CONFIG')) {
    std.setenv('JAVA_HOME', shellReadYamlJavaHome(std.getenv('ZWE_CLI_PARAMETER_CONFIG')));
  }
  if (!std.getenv('JAVA_HOME')) {
    std.setenv('JAVA_HOME', detectJavaHome());
  }
  if (!std.getenv('JAVA_HOME')) {
    common.printErrorAndExit("Error ZWEL0122E: Cannot find java. Please define JAVA_HOME environment variable.", undefined, 122);
  }

  ensureJavaIsOnPath();
}

export function validateJavaHome(javaHome:string=std.getenv("JAVA_HOME")): boolean {
  if (!javaHome) {
    common.printError("Cannot find java. Please define JAVA_HOME environment variable.");
    return false;
  }
  if (!fs.fileExists(fs.resolvePath(javaHome,`/bin/java`))) {
    common.printError(`JAVA_HOME: ${javaHome}/bin does not point to a valid install of Java.`);
    return false;
  }

  let execReturn = shell.execOutSync(fs.resolvePath(javaHome,`/bin/java`), `-version`);
  const version = execReturn.out;
  if (execReturn.rc != 0) {
    common.printError(`Java version check failed with return code: ${execReturn.rc}: ${version}`);
    return false;
  }
 
  try {
    let index = 0;
    let javaVersionShort;
    let versionLines = version.split('\n');
    for (let i = 0; i < versionLines.length; i++) {
      if ((index = versionLines[i].indexOf('java version')) != -1) {
        //format of: java version "1.8.0_321"
        javaVersionShort=versionLines[i].substring(index+('java version'.length)+2);
        break;
      } else if ((index = versionLines[i].indexOf('openjdk version')) != -1) {
        javaVersionShort=versionLines[i].substring(index+('openjdk version'.length)+2);
        break;
      }
    }
    let versionParts = javaVersionShort.split('.');
    const javaMajorVersion=versionParts[0];
    const javaMinorVersion=versionParts[1];

    let tooLow=false;
    if (javaMajorVersion != '1') {
      tooLow=true;
    }
    if (javaMajorVersion != '1' && Number(javaMinorVersion) < JAVA_MIN_VERSION) {
      tooLow=true;
    }

    if (tooLow) {
      common.printError(`Java ${javaVersionShort} is less than the minimum level required of Java ${JAVA_MIN_VERSION} (1.${JAVA_MIN_VERSION}.0).`);
      return false;
    }

    common.printDebug(`Java ${javaVersionShort} is supported.`);
    common.printDebug(`Java check is successful.`);
    return true;
  } catch (e) {
    return false;
  }
}
