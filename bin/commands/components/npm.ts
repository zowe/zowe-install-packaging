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


const registry = std.getenv('ZWE_CLI_PARAMETER_REGISTRY');
if (!registry) {
  console.log("ZWE_CLI_PARAMETER_REGISTRY required");
  std.exit(8);
}

//TODO npm has a notion of relating package prefixes to different registries.
//     this would allow different companies to have different registries.
//     we could consider there to be a DEFAULT registry, and then take input for prefix-specific overrides
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

node.requireNode();
//if its not in NODE_HOME, it might be on PATH.
const npm = std.getenv('NODE_HOME') ? std.getenv('NODE_HOME')+'/bin/npm' : 'npm';


if (!std.getenv('ZWE_zowe_extensionDirectory')) {
  console.log("ZWE_zowe_extensionDirectory required");
  std.exit(8);
}
const HANDLER_HOME = `${std.getenv('ZWE_zowe_extensionDirectory')}/.zowe/handlers/npm`

function npmExec(command: string, path?: string): number {
  let fullString: string = path ? `cd ${path} && ${npm} ` : `${npm} `;
  fullString+=command;
  
  if (path && !fs.directoryExists(path)) {
    console.log("Path does not exist. Path="+path);
    return 8;
  } else {
    const result = shell.execSync('sh', '-c', fullString);
    return result.rc;
  }
}


//NOTE: zwe API doesnt standardize output, so we just pass through whatever npm formats search as
function doSearch(registry: string, query: string): number {
  return npmExec(`search ${query} --registry=${registry}`);
}

function doInstall(registry: string, query: string, isUpgrade: boolean, dryRun: boolean): { rc: number, packages: string } {
  if (!isUpgrade) {
    if (fs.directoryExists(`${HANDLER_HOME}/node_modules/${query}`)) {
      console.log(`Component ${query} is already installed with npm.`);
      return { rc: 8, packages: 'null' };
    }
  } else {
    npmExec(`outdated ${query} --registry=${registry}`, HANDLER_HOME);
  }

  const packageLockLocation = `${HANDLER_HOME}/package-lock.json`;
  const innerPackageLockLocation = `${HANDLER_HOME}/node_modules/.package-lock.json`;
  
  let packagesBefore = [];
  if (fs.fileExists(packageLockLocation)) {
    const packageLockBefore = xplatform.loadFileUTF8(packageLockLocation,xplatform.AUTO_DETECT);
    const packageJson = JSON.parse(packageLockBefore);
    if (packageJson?.packages) {
      packagesBefore = Object.keys(packageJson.packages);
    }
    if (fs.fileExists(innerPackageLockLocation)) {
      fs.cp(innerPackageLockLocation, `innerPackageLockLocation.bkp`);
    }
  } 
  const installRc = npmExec(`${isUpgrade? 'update' : 'install'} ${dryRun? '--dry-run --no-package-lock --no-save ' : ''}${query} --registry=${registry}`, HANDLER_HOME);
  if (isUpgrade && dryRun) {
    //Dumb npm thing? I say dry run and it still writes things and gets itself confused.
    if (fs.fileExists(innerPackageLockLocation)) {
      fs.cp(`innerPackageLockLocation.bkp`, innerPackageLockLocation);
    }
  }

  let installedPackages = 'null';
  if (installRc == 0) {

    //TODO I also have a concern about how we can pass-through semver version queries during the install command. i think zwe can only play dumb, as stripping the symbols in the name could cause an issue???? or is it just that we can strip anything not in reverse-domain-notation
    
    const packageLockAfter = xplatform.loadFileUTF8(packageLockLocation,xplatform.AUTO_DETECT); 
    const packagesAfter = Object.keys(JSON.parse(packageLockAfter).packages);
    installedPackages = packagesAfter.filter(aPackage => aPackage != '' && !packagesBefore.includes(aPackage))
      // this path may already include node_modules and thats ok.
      .map(packagePath => `${HANDLER_HOME}/${packagePath}`)
      .map((packagePath) => {
        const packageJsonFile = xplatform.loadFileUTF8(`${packagePath}/package.json`, xplatform.AUTO_DETECT);
        const packageJsonContents = JSON.parse(packageJsonFile);
        //We return a list of files and folders which are to be installed as components
        //NOTE: components must not depend on node modules in the npm way at this level since locating node_modules in here would be strange
        //Instead, they should bundle their node dependencies. Dependencies in this handler are really about between zowe components, not node code.
        return packageJsonContents.main ? `${packagePath}/${packageJsonContents.main}` : packagePath;
      })
      .join(',');
    if (!installedPackages) { installedPackages = 'null' };
  }
  return { rc: installRc, packages: installedPackages };
}


function doUpgradeAll(registry: string, dryRun: boolean): { rc: number, packages: string } {
  const componentNames = fs.getSubdirectories(HANDLER_HOME);
  if (!componentNames) {
    console.log("No components found to do upgrade on");
    return { rc: 0, packages: 'null' };
  }
  let highestRc = 0;
  let newPackages = '';
  componentNames.forEach((componentName: string) => {
    let result = doInstall(registry, componentName, true, dryRun);
    if (result.packages != 'null') {
      newPackages+=','+result.packages;
    }
    if (result.rc > highestRc) {
      highestRc = result.rc;
    }
  });
  if (!newPackages) { newPackages = 'null' };
  return { rc: highestRc, packages: newPackages };
}



//TODO when you npm uninstall, you uninstall dependencies not needed by anyone else. this should iterate over the list of changes.
function doUninstall(registry: string, query: string): { rc: number, packages: string } {

  const packageLockLocation = `${HANDLER_HOME}/package-lock.json`;
  //TODO a dry-run of our own could be done by running through the package-lock.json tree and saying what we believe would be removed with this operation,
  //     or if the operation is even possible without removing other things.

  let packagesBefore = [];
  if (fs.fileExists(packageLockLocation)) {
    const packageLockBefore = xplatform.loadFileUTF8(packageLockLocation, xplatform.AUTO_DETECT);
    const packageJson = JSON.parse(packageLockBefore);
    if (packageJson?.dependencies) {
      packagesBefore = Object.keys(packageJson.dependencies);
    }
  } 
  
  const uninstallRc = npmExec(`uninstall ${query} --registry=${registry}`, HANDLER_HOME);
  let uninstalledPackages = 'null';
  if (uninstallRc == 0) {
    const packageLockAfter = xplatform.loadFileUTF8(packageLockLocation, xplatform.AUTO_DETECT);
    const packageJsonAfter = JSON.parse(packageLockAfter);
    const packagesAfter = packageJsonAfter.dependencies ? Object.keys(packageJsonAfter.dependencies) : [];
    //We return just the package names aka component names, so that zwe can act upon those it knows about
    uninstalledPackages = packagesBefore.filter(aPackage => aPackage != '' && !packagesAfter.includes(aPackage)).join(',');
    if (!uninstalledPackages) { uninstalledPackages = 'null' };
  }

  return { rc: uninstallRc, packages: uninstalledPackages };
}


function doGetPath(component: string): string {
  const components = component === 'all'
    ? fs.getSubdirectories(HANDLER_HOME)
    : [ component ];

  if (!components) {
    return 'null';
  }
  let paths = [];
  components.forEach((component: string)=> {
    // Yes really, component/component. its just due to how i had to fake out npm
    // TODO super long path, windows is sure to complain
    const path = `${HANDLER_HOME}/node_modules/${component}`;
    if (fs.directoryExists(path)) {
      const packageFile = xplatform.loadFileUTF8(`${path}/package.json`,xplatform.AUTO_DETECT);
      if (packageFile) {
        const packageJson = JSON.parse(packageFile);
        //If a zowe npm package is just an archive, list its filename in main. else, we assume the entire directory is the package.
        paths.push(packageJson.main ? `${path}/${packageJson.main}` : path);
      } else {
        console.log(`No package.json found for ${path}`);
        paths.push('null');
      }
    } else {
      //TODO doing this as a precaution of shell hang if no output. does that still happen?
      paths.push('null');
    }
  });
  return paths.join(',');
}



//init
if (!fs.directoryExists(HANDLER_HOME)) {
  fs.mkdirp(HANDLER_HOME);
  // to /dev/null to hide this hack
  //TODO and what about windows?
  const initRc = npmExec(`init -y > /dev/null`, HANDLER_HOME);
  if (initRc) {
    fs.rmrf(HANDLER_HOME);
    std.exit(initRc);
  }    
}

switch (command) {
case 'search': {
  const rc = doSearch(registry, componentName ? componentName : componentId);
  std.exit(rc);
  break;
  }
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
//  break;
}
default:
  console.log("Unsupported command="+command);
  std.exit(8);
}
