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
import { PathAPI as pathoid } from './pathoid';

const NODE_MIN_VERSION=16;

// enforce encoding of stdio/stdout/stderr
// sometimes /dev/tty* ($SSH_TTY) are not configured properly, for example tagged as binary or wrong encoding
std.setenv('NODE_STDOUT_CCSID','1047');
std.setenv('NODE_STDERR_CCSID','1047');
std.setenv('NODE_STDIN_CCSID','1047');
  
// Workaround Fix for node 8.16.1 that requires compatibility mode for untagged files
std.setenv('__UNTAGGED_READ_MODE','V6');


export function ensureNodeIsOnPath(): void {
  let path=std.getenv('PATH') || '/bin:.:/usr/bin';
  let nodeHome=std.getenv('NODE_HOME');
  if (!path.includes(`:${nodeHome}/bin:`)) {
    std.setenv('PATH', `${nodeHome}/bin:${path}`);
  }
}

export function shellReadYamlNodeHome(configList?: string, skipValidate?: boolean): string {
  const zoweConfig = config.getZoweConfig();
  if (zoweConfig && zoweConfig.node && zoweConfig.node.home) {
    if (!skipValidate) {
      if (!validateNodeHome(zoweConfig.node.home)) {
        return '';
      }
    }
    return zoweConfig.node.home;
  }
  return '';
}

export function detectNodeHome(): string|undefined {
  let nodeBinHome = shell.which(`node`);
  if (nodeBinHome) {
    let returnVal = pathoid.normalize(`${nodeBinHome}/../..`);
    return returnVal;
  }
  return undefined;
}

let _checkComplete = false;
export function requireNode() {
  if ((_checkComplete === true) && std.getenv('NODE_HOME')) {
    return;
  }
  if (std.getenv('ZWE_CLI_PARAMETER_CONFIG')) {
    const customNodeHome = shellReadYamlNodeHome();
    if (customNodeHome) {
      std.setenv('NODE_HOME', customNodeHome);
    }
  }
  if (!std.getenv('NODE_HOME')) {
    let discoveredHome = detectNodeHome();
    if (discoveredHome){
      std.setenv('NODE_HOME', discoveredHome);
    }
  }
  if (!std.getenv('NODE_HOME')) {
    common.printErrorAndExit("Error ZWEL0121E: Cannot find node. Please define NODE_HOME environment variable.", undefined, 121);
  }

  ensureNodeIsOnPath();
  _checkComplete = true;
}

export function validateNodeHome(nodeHome:string|undefined=std.getenv("NODE_HOME")): boolean {
  if (!nodeHome) {
    common.printError("Cannot find node. Please define NODE_HOME environment variable.");
    return false;
  }
  if (!fs.fileExists(fs.resolvePath(nodeHome,`/bin/node`))) {
    common.printError(`NODE_HOME: ${nodeHome}/bin does not point to a valid install of Node.`);
    return false;
  }

  let shellReturn = shell.execOutSync(fs.resolvePath(nodeHome,`/bin/node`), `--version`);
  const version = shellReturn.out;
  if (shellReturn.rc != 0) {
    common.printError(`Node version check failed with return code: ${shellReturn.rc}: ${version}`);
    return false;
  }
 
  try {
    if ((version as string).startsWith('v')) { // valid because rc check
      let parts = (version as string).split('.');
      const nodeMajorVersion = Number(parts[0].substring(1));
      //const nodeMinorVersion = Number(parts[1]);
      //const nodePatchVersion = Number(parts[2]);

      if (version == 'v18.12.1') {
        common.printError(`Node ${version} specifically is not compatible with Zowe. Please use a different version. See https://github.com/ibmruntimes/node-zos/issues/21 for more details.`);
        return false;
      }

      if (nodeMajorVersion < NODE_MIN_VERSION) {
        common.printError(`Node ${version} is less than the minimum level required of v${NODE_MIN_VERSION}.`);
        return false;
      }
      common.printDebug(`Node ${version} is supported.`)

      shellReturn = shell.execOutSync(fs.resolvePath(nodeHome,`/bin/node`), `-e`, "const process = require('process'); console.log('ok'); process.exit(0);");
      const ok = shellReturn.out;
      if (ok != 'ok' || shellReturn.rc != 0) {
        common.printError(`${nodeHome}/bin/node is not functioning correctly (exit code ${shellReturn.rc}): '${ok}', len=${ok.length}`);
        return false;
      }

      common.printDebug(`Node check is successful.`);
      
      return true;
    } else {
      common.printError(`Cannot validate node version '${version}'. Unexpected format`);
      return false;
    }
  } catch (e) {
    return false;
  }
}
