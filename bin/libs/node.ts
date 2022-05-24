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

import * as fs from './fs';
import * as common from './common';
import * as shell from './shell';
import * as config from './config';

const NODE_MIN_VERSION=12;

// enforce encoding of stdio/stdout/stderr
// sometimes /dev/tty* ($SSH_TTY) are not configured properly, for example tagged as binary or wrong encoding
std.setenv('NODE_STDOUT_CCSID','1047');
std.setenv('NODE_STDERR_CCSID','1047');
std.setenv('NODE_STDIN_CCSID','1047');
  
// Workaround Fix for node 8.16.1 that requires compatibility mode for untagged files
std.setenv('__UNTAGGED_READ_MODE','V6');


export function ensureNodeIsOnPath(): void {
  let path=std.getenv('PATH');
  let nodeHome=std.getenv('NODE_HOME');
  if (!path.includes(`:${nodeHome}/bin:`)) {
    std.setenv('PATH', `${nodeHome}/bin:${path}`);
  }
}

export function shellReadYamlNodeHome(configList?: string, skipValidate?: boolean): string {
  const zoweConfig = config.getZoweConfig();
  if (zoweConfig && zoweConfig.node && zoweConfig.node.home) {
    if (!skipValidate) {
      if (validateNodeHome(zoweConfig.node.home)) {
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
    let returnVal = std.realpath(`${nodeBinHome}/../..`);
    if (!returnVal[1]) {
      return returnVal[0];
    }
  }
  return undefined;
}

export function requireNode() {
  if (std.getenv('ZWE_CLI_PARAMETER_CONFIG')) {
    std.setenv('NODE_HOME', shellReadYamlNodeHome());
  }
  if (!std.getenv('NODE_HOME')) {
    std.setenv('NODE_HOME', detectNodeHome());
  }
  if (!std.getenv('NODE_HOME')) {
    common.printErrorAndExit("Error ZWEL0121E: Cannot find node. Please define NODE_HOME environment variable.", undefined, 121);
  }

  ensureNodeIsOnPath();
}

export function validateNodeHome(nodeHome:string=std.getenv("NODE_HOME")): boolean {
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
    if (version.startsWith('v')) {
      let parts = version.split('.');
      const nodeMajorVersion = Number(parts[0].substring(1));
      //const nodeMinorVersion = Number(parts[1]);
      //const nodePatchVersion = Number(parts[2]);

      if (version == 'v14.17.2') {
        common.printError(`Node ${version} specifically is not compatible with Zowe. Please use a different version. See https://docs.zowe.org/stable/troubleshoot/app-framework/app-known-issues.html#desktop-apps-fail-to-load for more details.`);
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
        common.printError(`${nodeHome}/bin/node is not functioning correctly (exit code ${shellReturn.rc}): ${ok}`);
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
