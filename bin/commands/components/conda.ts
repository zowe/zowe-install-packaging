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


/*
 *
 *
 *
 *
 *
 * NOTE: this file is incomplete and excluded from running at this time.
 *
 */

import * as std from 'cm_std';
import * as os from 'cm_os';
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

const conda = std.getenv('ZWE_zowe_extensionRegistry_handlers_conda_condapath');
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


/*
  --copy                Install all packages using copies instead of hard- or
                        soft-linking.

  --update-dependencies, --update-deps
                        Update dependencies. Overrides the value given by
                        `conda config --show update_deps`.
  --no-update-dependencies, --no-update-deps
                        Don't update dependencies. Overrides the value given
                        by `conda config --show update_deps`.
  --json                Report all output as json. Suitable for using conda
                        programmatically.
  --debug               Show debug output.
  --verbose, -v         Use once for info, twice for debug, three times for
                        trace.
*/

//conda install -c channel -p pathofenv -y --dry-run -q  packagename


//conda update -c channel -p pathofenv -y --dry-run -q --all packagename
function doInstall(registries: string[], query: string, isUpgrade: boolean, dryRun: boolean): { rc: number, packages: string } {
  const metaLocation = `${HANDLER_HOME}/conda-meta`;
  
  let packagesBefore = fs.getFilesInDirectory(metaLocation);
  if (!packagesBefore) {
    packagesBefore = [];
  }

  const installRc = condaExec(`${isUpgrade? 'update' : 'install'} -p ${HANDLER_HOME} ${dryRun? '--dry-run ' : ''}${query}`, registries);


  let installedPackages = 'null';
  if (installRc == 0) {
    const packagesAfter = fs.getFilesInDirectory(metaLocation);
    installedPackages = packagesAfter.filter((packageName: string) => {
        if (packageName == 'history') {
          return false;
        } else if (!packagesBefore[packageName]) { //something new, or a new version.
          return true;
        } else {
          return false;
        }
      //TODO upgrades could also REMOVE no longer needed dependencies. this should send back added/removed seperately.
      })
      .map((packageName) => {
        //file appears to be ASCII, untagged on z/os
        const jsonFile = xplatform.loadFileUTF8(`${HANDLER_HOME}/conda-meta/${packageName}`, 0);
        const jsonContents = JSON.parse(jsonFile);
        //We return a list of files and folders which are to be installed as components
        //NOTE: components must not depend on other conda packages in non-zowe ways since locating other packages within conda could be an issue
        //Instead, they should bundle their dependencies. Dependencies in this handler are really about between zowe components.
        const componentDir = `${HANDLER_HOME}/var/zowe/components/${jsonContents.version}/${jsonContents.name}`;
        if (!fs.directoryExists(componentDir)) {
          return 'null';
        } else {
          const componentFiles = fs.getFilesInDirectory(componentDir);
          for (let i = 0; i < componentFiles.length; i++) {
            if (componentFiles[i].endsWith('.pax')
                ||componentFiles[i].endsWith('.tar')
                ||componentFiles[i].endsWith('.zip')) {
              //If an archive exists within, the first one we find MUST be the component archive.
              return `${componentDir}/${componentFiles[i]}`;
            }
          }
          //If no archive found, the directory is the zowe component.
          return componentDir;
        }
      })
      .filter(packagePath => packagePath != 'null')
      .join(',');
    if (!installedPackages) { installedPackages = 'null' };
  }
  return { rc: installRc, packages: installedPackages };
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

case 'install': {
  const result = doInstall(REGISTRIES, componentName ? componentName : componentId, false, dryRun);
  console.log('ZWE_CLI_PARAMETER_COMPONENT_FILE='+result.packages);
  std.exit(result.rc);
  break;
  }
/*
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


