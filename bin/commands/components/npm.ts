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
import * as common from '../../libs/common';
import * as shell from '../../libs/shell';
import * as node from '../../libs/node';
import * as fs from '../../libs/fs';

const registry = std.getenv('ZWE_CLI_PARAMETER_REGISTRY');
if (!registry) {
  common.printMessage("ZWE_CLI_PARAMETER_REGISTRY required");
  std.exit(8);
}
const command = std.getenv('ZWE_CLI_REGISTRY_COMMAND');
if (!command) {
  common.printMessage("ZWE_CLI_REGISTRY_COMMAND required");
  std.exit(8);
}
const componentName = std.getenv('ZWE_CLI_PARAMETER_COMPONENT_NAME');
const componentId = std.getenv('ZWE_CLI_PARAMETER_COMPONENT_ID');
if (!componentName && !componentId) {
  common.printMessage("ZWE_CLI_PARAMETER_COMPONENT_NAME or ZWE_CLI_PARAMETER_COMPONENT_ID required");
  std.exit(8);
}

node.requireNode();
//if its not in NODE_HOME, it might be on PATH.
const npm = std.getenv('NODE_HOME') ? std.getenv('NODE_HOME')+'/bin/npm' : 'npm';

function npmExec(command: string, path?: string): any {
  if (path && !fs.directoryExists(path)) {
    common.printMessage("Path does not exist. Path="+path);
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
  if (!std.getenv('ZWE_zowe_extensionsDirectory')) {
    common.printMessage("ZWE_zowe_extensionsDirectory required");
    std.exit(8);
  }

  const destination = `${std.getenv('ZWE_zowe_extensionsDirectory')}/.zowe/handlers/npm/${query}`;
  fs.mkdirp(destination);
  const result = npmExec(`install ${query} --registry=${registry}`, destination);
  return result.rc;
}

function doUninstall(registry: string, query: string): number {
  if (!std.getenv('ZWE_zowe_extensionsDirectory')) {
    common.printMessage("ZWE_zowe_extensionsDirectory required");
    std.exit(8);
  }

  const destination = `${std.getenv('ZWE_zowe_extensionsDirectory')}/.zowe/handlers/npm/${query}`;
  if (fs.directoryExists(destination)) {
    return fs.rmrf(destination);
  }
  return 0;
}


function doGetPath(component: string): string {
  if (!std.getenv('ZWE_zowe_extensionsDirectory')) {
    common.printMessage("ZWE_zowe_extensionsDirectory required");
    std.exit(8);
  }

  const path = `${std.getenv('ZWE_zowe_extensionsDirectory')}/.zowe/handlers/npm/${component}`;
  if (fs.directoryExists(path)) {
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
    common.printMessage(path);
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
  common.printMessage("Unsupported command="+command);
  std.exit(8);
}
