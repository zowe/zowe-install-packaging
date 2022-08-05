/*
// This program and the accompanying materials are made available
// under the terms of the Eclipse Public License v2.0 which
// accompanies this distribution, and is available at
// https://www.eclipse.org/legal/epl-v20.html
//
// SPDX-License-Identifier: EPL-2.0
//
// Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as os from 'os';
import * as xplatform from 'xplatform';
import * as common from '../../libs/common';
import * as shell from '../../libs/shell';
import * as node from '../../libs/node';
import * as fs from '../../libs/fs';

declare namespace console {
  function log(...args:string[]): void;
};


//TODO conda has a notion of multiple registries (channels)
//     this would allow for different companies to have different registries.
//     we could consider there to be a DEFAULT registry, but have a list of alternatives, perhaps on a prefix-specific override basis
const REGISTRIES = std.getenv('ZWE_CLI_PARAMETER_REGISTRY') ? [ std.getenv('ZWE_CLI_PARAMETER_REGISTRY') ] : undefined;
if (!REGISTRIES) {
  console.log("ZWE_CLI_PARAMETER_REGISTRY required");
  std.exit(8);
}
const command = std.getenv('ZWE_CLI_REGISTRY_COMMAND');
if (!command) {
  console.log("ZWE_CLI_REGISTRY_COMMAND required");
  std.exit(8);
}
const componentName = std.getenv('ZWE_CLI_PARAMETER_COMPONENT_NAME');
const componentId = std.getenv('ZWE_CLI_PARAMETER_COMPONENT_ID');
if (!componentName && !componentId) {
  console.log("ZWE_CLI_PARAMETER_COMPONENT_NAME or ZWE_CLI_PARAMETER_COMPONENT_ID required");
  std.exit(8);
}

const dryRun: boolean = std.getenv('ZWE_CLI_REGISTRY_DRY_RUN') === 'true';

const conda = std.getenv('ZWE_zowe_handlers_conda_condapath');
if (!conda || !fs.fileExists(conda)) {
  console.log("Conda not found! Define zowe.handlers.conda.condapath as the path to the conda executable.");
  std.exit(8);
}

if (!std.getenv('ZWE_zowe_extensionDirectory')) {
  console.log("ZWE_zowe_extensionDirectory required");
  std.exit(8);
}
const HANDLER_HOME = `${std.getenv('ZWE_zowe_extensionDirectory')}/.zowe/handlers/conda`


function condaExec(command: string, registries: string[]): number {
  registries.forEach((registry:string) => {
    command+=` -c ${registry}`;
  });

  const fullString = `${conda} ${command}`;
  const result = shell.execSync('sh', '-c', fullString);
  return result.rc;
}

function condaInit(registries: string[]): number {
  let command = `create -p ${HANDLER_HOME} -q -y`;
  return condaExec(command, registries);
}

//NOTE: zwe API doesnt standardize output, so we just pass through whatever npm formats search as
function doSearch(registries: string[], query: string): number {
  return condaExec(`search -p ${HANDLER_HOME} ${query}`, registries);
}



//init
if (!fs.directoryExists(HANDLER_HOME)) {
  const initRc = condaInit(REGISTRIES);
  if (initRc) {
    fs.rmrf(HANDLER_HOME);
    std.exit(initRc);
  }
}


switch (command) {
case 'search': {
  const rc = doSearch(REGISTRIES, componentName ? componentName : componentId);
  std.exit(rc);
  break;
}
  /*
case 'install': {
  const result = doInstall(registry, componentName ? componentName : componentId, false, dryRun);
  console.log('ZWE_CLI_PARAMETER_COMPONENT_FILE='+result.packages);
  std.exit(result.rc);
  break;
  }
case 'upgrade': {
  const component = componentName ? componentName : componentId;
  if (component === 'all') {
    const result = doUpgradeAll(registry, dryRun);
    console.log('ZWE_CLI_PARAMETER_COMPONENT_FILE='+result.packages);
    std.exit(result.rc);
  } else {
    const result = doInstall(registry, component, true, dryRun);
    console.log('ZWE_CLI_PARAMETER_COMPONENT_FILE='+result.packages);
    std.exit(result.rc);
  }
  break;
  }

case 'getpath': {
  const path = doGetPath(componentName ? componentName : componentId);
  console.log('ZWE_CLI_PARAMETER_COMPONENT_FILE='+path);
  std.exit(path==='null' ? 8 : 0);
  break;
  }
case 'uninstall': {
  const result = doUninstall(registry, componentName ? componentName : componentId);
  console.log('ZWE_CLI_PARAMETER_COMPONENT_NAME='+result.packages);
  std.exit(result.rc);
  break;
}
case 'cleanup': {
  //TODO if something failed and left behind junk, or there was a cache... clean it.
  break;
}
*/
default:
  console.log("Unsupported command="+command);
  std.exit(8);
}


