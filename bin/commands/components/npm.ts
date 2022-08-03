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
import * as xplatform from 'xplatform';
import * as common from '../../libs/common';
import * as shell from '../../libs/shell';
import * as node from '../../libs/node';
import * as fs from '../../libs/fs';

declare namespace console {
  function log(...args:string[]): void;
};


const registry = std.getenv('ZWE_CLI_PARAMETER_REGISTRY');
if (!registry) {
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

node.requireNode();
//if its not in NODE_HOME, it might be on PATH.
const npm = std.getenv('NODE_HOME') ? std.getenv('NODE_HOME')+'/bin/npm' : 'npm';

function npmExec(command: string, path?: string): any {
  if (path && !fs.directoryExists(path)) {
    console.log("Path does not exist. Path="+path);
    return 8;
  } else if (path) {
    return shell.execSync('sh', '-c', `cd "${path}" && ${npm} ${command}`);
  } else {
    return shell.execSync('sh', '-c', `${npm} ${command}`);
  }
}


//NOTE: API doesnt standardize output, so we just pass through whatever npm formats search as
function doSearch(registry: string, query: string): number {
  const result = npmExec(`search ${query} --registry=${registry}`);
  return result.rc;
}

function doInstall(registry: string, query: string): number {
  if (!std.getenv('ZWE_zowe_extensionDirectory')) {
    console.log("ZWE_zowe_extensionDirectory required");
    std.exit(8);
  }

  const destination = `${std.getenv('ZWE_zowe_extensionDirectory')}/.zowe/handlers/npm/${query}`;
  const isUpgrade = fs.directoryExists(destination); //TODO should this really upgrade, or should it fail?
  if (!isUpgrade) {
    fs.mkdirp(destination);
    // to /dev/null to hide this hack
    //TODO and what about windows?
    const initResult = npmExec(`init -y > /dev/null`, destination);
    if (initResult.rc) {
      fs.rmrf(destination);
      return initResult.rc;
    }
  }
  const installResult = npmExec(`install ${query} --registry=${registry}`, destination);
  if (installResult.rc && !isUpgrade) {
    fs.rmrf(destination);
  }
  return installResult.rc;
}

function doUninstall(registry: string, query: string): number {
  if (!std.getenv('ZWE_zowe_extensionDirectory')) {
    console.log("ZWE_zowe_extensionDirectory required");
    std.exit(8);
  }

  const destination = `${std.getenv('ZWE_zowe_extensionDirectory')}/.zowe/handlers/npm/${query}`;
  if (fs.directoryExists(destination)) {
    return fs.rmrf(destination);
  }
  return 0;
}


function doGetPath(component: string): string {
  if (!std.getenv('ZWE_zowe_extensionDirectory')) {
    console.log("ZWE_zowe_extensionDirectory required");
    std.exit(8);
  }
  // Yes really, component/component. its just due to how i had to fake out npm
  // TODO super long path, windows is sure to complain
  const path = `${std.getenv('ZWE_zowe_extensionDirectory')}/.zowe/handlers/npm/${component}/node_modules/${component}`;
  if (fs.directoryExists(path)) {
    const packageFile = xplatform.loadFileUTF8(`${path}/package.json`,xplatform.AUTO_DETECT);
    if (packageFile) {
      const packageJson = JSON.parse(packageFile);
      //If a zowe npm package is just an archive, list its filename in main. else, we assume the entire directory is the package.
      return packageJson.main ? `${path}/${packageJson.main}` : path;
    }
    return path;
  } else {
    //TODO doing this as a precaution of shell hang if no output. does that still happen?
    return 'null';
  }
}

switch (command) {
case 'search': {
  const rc = doSearch(registry, componentName ? componentName : componentId);
  std.exit(rc);
  break;
  }
case 'install': {
  const rc = doInstall(registry, componentName ? componentName : componentId);
  std.exit(rc);
  break;
  }
case 'getpath': {
  const path = doGetPath(componentName ? componentName : componentId);
  if (path) {
    console.log(path);
    std.exit(0);
  } else {
    std.exit(8);
  }
  break;
  }
case 'uninstall': {
  std.exit(doUninstall(registry, componentName ? componentName : componentId));
  break;
  }
default:
  console.log("Unsupported command="+command);
  std.exit(8);
}
