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

function npmExec(command: string, path?: string): any {
  let fullString: string = path ? `cd ${path} && ${npm} ` : `${npm} `;
  fullString+=command;
  
  if (path && !fs.directoryExists(path)) {
    console.log("Path does not exist. Path="+path);
    return 8;
  } else {
    return shell.execSync('sh', '-c', fullString);
  }
}


//NOTE: API doesnt standardize output, so we just pass through whatever npm formats search as
function doSearch(registry: string, query: string): number {
  const result = npmExec(`search ${query} --registry=${registry}`);
  return result.rc;
}

function doInstall(registry: string, query: string, isUpgrade: boolean, dryRun: boolean): { rc: number, packages: string } {
  if (!std.getenv('ZWE_zowe_extensionDirectory')) {
    console.log("ZWE_zowe_extensionDirectory required");
    return { rc: 8, packages: 'null' };
  }

  const destination = `${std.getenv('ZWE_zowe_extensionDirectory')}/.zowe/handlers/npm`;
  //init
  if (!fs.directoryExists(destination)) {
    fs.mkdirp(destination);
    // to /dev/null to hide this hack
    //TODO and what about windows?
    const initResult = npmExec(`init -y > /dev/null`, destination);
    if (initResult.rc) {
      fs.rmrf(destination);
      return initResult.rc;
    }    
  }
  
  if (!isUpgrade) {
    if (fs.directoryExists(`${destination}/node_modules/${query}`)) {
      console.log(`Component ${query} is already installed with npm.`);
      return { rc: 8, packages: 'null' };
    }
  } else {
    npmExec(`outdated ${query} --registry=${registry}`, destination);
  }

  const packageLockLocation = `${destination}/package-lock.json`;
  const innerPackageLockLocation = `${destination}/node_modules/.package-lock.json`;
  
  let packagesBefore = [];
  if (fs.fileExists(packageLockLocation)) {
    const packageLockBefore = xplatform.loadFileUTF8(packageLockLocation,xplatform.AUTO_DETECT);
    const packageJson = JSON.parse(packageLockBefore);
    if (packageJson?.packages) {
      packagesBefore = Object.keys(packageJson);
    }
    if (fs.fileExists(innerPackageLockLocation)) {
      fs.cp(innerPackageLockLocation, `innerPackageLockLocation.bkp`);
    }
  } 
  const installResult = npmExec(`${isUpgrade? 'update' : 'install'} ${dryRun? '--dry-run --no-package-lock --no-save ' : ''}${query} --registry=${registry}`, destination);
  if (isUpgrade && dryRun) {
    //Dumb npm thing? I say dry run and it still writes things and gets itself confused.
    if (fs.fileExists(innerPackageLockLocation)) {
      fs.cp(`innerPackageLockLocation.bkp`, innerPackageLockLocation);
    }
//    os.remove(innerPackageLockLocation);
  }

  let installedPackages = 'null';
  if (installResult.rc == 0) {

    //TODO I also have a concern about how we can pass-through semver version queries during the install command. i think zwe can only play dumb, as stripping the symbols in the name could cause an issue???? or is it just that we can strip anything not in reverse-domain-notation
    
    const packageLockAfter = xplatform.loadFileUTF8(packageLockLocation,xplatform.AUTO_DETECT); 
    const packagesAfter = Object.keys(JSON.parse(packageLockAfter).packages);
    installedPackages = packagesAfter.filter(aPackage => aPackage != '' && !packagesBefore.includes(aPackage))
    // this may already include node_modules
      .map(packageName => `${destination}/${packageName}`)
      .map((packagePath) => {
        const packageJsonFile = xplatform.loadFileUTF8(`${packagePath}/package.json`, xplatform.AUTO_DETECT);
        const packageJsonContents = JSON.parse(packageJsonFile);
        return packageJsonContents.main ? `${packagePath}/${packageJsonContents.main}` : packagePath;
      })
      .join(',');
    if (!installedPackages) { installedPackages = 'null' };
  }
  return { rc: installResult.rc, packages: installedPackages };
}


function doUpgradeAll(registry: string, dryRun: boolean): { rc: number, packages: string } {
  if (!std.getenv('ZWE_zowe_extensionDirectory')) {
    console.log("ZWE_zowe_extensionDirectory required");
    return { rc: 8, packages: 'null' };
  }

  const root = `${std.getenv('ZWE_zowe_extensionDirectory')}/.zowe/handlers/npm`;
  const componentNames = fs.getSubdirectories(root);
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
function doUninstall(registry: string, query: string): number {
  if (!std.getenv('ZWE_zowe_extensionDirectory')) {
    console.log("ZWE_zowe_extensionDirectory required");
    return 8;
  }

  const destination = `${std.getenv('ZWE_zowe_extensionDirectory')}/.zowe/handlers/npm`;
  const uninstallResult = npmExec(`uninstall ${query} --registry=${registry}`, destination);
  return uninstallResult.rc;
}


function doGetPath(component: string): string {
  if (!std.getenv('ZWE_zowe_extensionDirectory')) {
    console.log("ZWE_zowe_extensionDirectory required");
    return 'null';
  }

  const components = component === 'all'
    ? fs.getSubdirectories(`${std.getenv('ZWE_zowe_extensionDirectory')}/.zowe/handlers/npm`)
    : [ component ];

  if (!components) {
    return 'null';
  }
  let paths = [];
  components.forEach((component: string)=> {
    // Yes really, component/component. its just due to how i had to fake out npm
    // TODO super long path, windows is sure to complain
    const path = `${std.getenv('ZWE_zowe_extensionDirectory')}/.zowe/handlers/npm/node_modules/${component}`;
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
  std.exit(doUninstall(registry, componentName ? componentName : componentId));
  break;
}
case 'cleanup': {
  //TODO if something failed and left behind junk, or there was a cache... clean it.
  break;
}
default:
  console.log("Unsupported command="+command);
  std.exit(8);
}
