/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as fs from './fs';
import * as common from './common';
import * as shell from './shell';

const JAVA_MIN_VERSION=17;

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
