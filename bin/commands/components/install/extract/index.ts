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
import * as zos from 'zos';
import * as xplatform from 'xplatform';

import * as fs from '../../../../libs/fs';
import * as common from '../../../../libs/common';
import * as stringlib from '../../../../libs/string';
import * as shell from '../../../../libs/shell';
import * as sys from '../../../../libs/sys';
import * as config from '../../../../libs/config';
import * as component from '../../../../libs/component';
import * as varlib from '../../../../libs/var';
import * as java from '../../../../libs/java';
import * as node from '../../../../libs/node';
import * as zosmf from '../../../../libs/zosmf';
import { PathAPI as pathoid } from '../../../../libs/pathoid';


//TODO does this handle componentFile relative paths correctly or not
export function execute(componentFile: string, autoEncoding?: string, upgrade?: boolean): string {
  //////////////////////////////////////////////////////////////
  // Constants
  const pwd = std.getenv('ZWE_PWD');
  const moduleFileShort=pathoid.basename(componentFile);
  const tmp_ext_dir='tmp_'+moduleFileShort; //TODO this is a hack about getManifest() caching result per directory. The caching could be avoided by versioning, need to implement in component.ts later...
  const ZOWE_CONFIG=config.getZoweConfig();
  
  //////////////////////////////////////////////////////////////
  common.requireZoweYaml();
  let result;
  let rc;  
  
  //////////////////////////////////////////////////////////////
  // read extensionDirectory
  const extensionDir=ZOWE_CONFIG.zowe.extensionDirectory;
  if (!extensionDir) {
    common.printErrorAndExit("Error ZWEL0180E: Zowe extension directory (zowe.extensionDirectory) is not defined in Zowe YAML configuration file.", undefined, 180);
  }

  // Variables
  const targetDir = pathoid.isAbsolute(extensionDir) ? stringlib.removeTrailingSlash(extensionDir) : stringlib.removeTrailingSlash(pathoid.resolve(pwd, extensionDir));
  const tmpDir = pathoid.resolve(targetDir, tmp_ext_dir);


  //////////////////////////////////////////////////////////////
  // check existence of extension directory, create if it's not there
  if (!fs.directoryExists(targetDir)) {
    fs.mkdirp(targetDir);  
  }
  
  if (!fs.directoryExists(targetDir)) {
    common.printErrorAndExit(`Error ZWEL0139E: Failed to create directory ${targetDir}.`, undefined, 139);
  }

  componentFile = stringlib.removeTrailingSlash(fs.convertToAbsolutePath(componentFile) as string)
  
  //////////////////////////////////////////////////////////////
  // clean up
  if (targetDir=='/') {
    common.printErrorAndExit("Error ZWEL0153E: Cannot install Zowe component to system root directory.", undefined, 153);
  }
  if (!tmpDir) {
    common.printErrorAndExit( "Error ZWEL0154E: Temporary directory is empty.", undefined, 154);
  }

  fs.rmrf(tmpDir);

  common.printMessage(`Install ${moduleFileShort}`);

  if (fs.directoryExists(componentFile)) {
    common.printDebug(`- Module ${componentFile} is a directory, will create symbolic link into target directory.`);
    //TODO do i need to set link name
    rc = os.symlink(componentFile, tmpDir);
    if (rc) {
      common.printErrorAndExit(`Error ZWEL0204E: Symlink creation failure, error=${rc}`, undefined, 204);
    }
  } else if (fs.fileExists(componentFile)) {
    // create temporary directory to lay down extension files in
    fs.mkdirp(tmpDir);
    
    common.printDebug(`- Extract file ${moduleFileShort} to temporary directory.`);

    if (componentFile.endsWith('.pax')) {
      result = shell.execSync('sh', '-c', `cd ${tmpDir} && pax -ppx -rf ${componentFile}`);
    } else if (componentFile.endsWith('.zip')) {
      java.requireJava();
      result = shell.execSync('sh', '-c', `cd ${tmpDir} && jar xf ${componentFile}`);
    } else if (componentFile.endsWith('.tar')) {
      result = shell.execSync('sh', '-c', `_CEE_RUNOPTS="FILETAG() POSIX(ON)" cd ${tmpDir} && pax -x tar -rf "${componentFile}"`);
    }
    if (result.rc) {
      common.printError(`Extract completed with rc=${result.rc}`);
    }
    common.printTrace("  * List extracted files:");
    result = shell.execOutSync('sh', '-c', `cd ${tmpDir} && ls -la 2>&1`);
    common.printTrace(stringlib.paddingLeft(result.out, "    "));
  } else {
    common.printErrorAndExit(`Error ZWEL0313E: Cannot file component file ${componentFile}.`, undefined, 313);
  }

  // automatically tag files
  if (os.platform == 'zos') {
    const manifestEncoding=component.detectComponentManifestEncoding(tmpDir);
    common.printDebug(`- Requested auto_encoding=${autoEncoding}, component manifest encoding is ${manifestEncoding}.`);
    //the autotag script we have is for tagging when files are ascii, so we assume tagging cant be done unless ascii
    let autotag="no";

    if (manifestEncoding==819) {
      const isTagged=component.detectIfComponentTagged(tmpDir);
      // unless explicitly asked to tag, if component is already tagged, retag could produce errors
      if (isTagged === true) {
        common.printDebug("  * Component tagged, so turning auto-encoding off");
        autotag="no";
      } else {
        common.printDebug("  * ASCII Component not tagged, so turning auto-encoding ON");
        autotag="yes";
      }
    }
    if (autoEncoding != 'no' && autotag == 'yes') {
      // automatically tag files
      common.printDebug("- Automatically tag files");
      result = shell.execOutSync('sh', '-c', `"${ZOWE_CONFIG.zowe.runtimeDirectory}/bin/utils/tag-files.sh" "${tmpDir}" 2>&1`);
      if (result.out) {
        common.printTrace(result.out);
      }

      common.printTrace("  * List tagged files:");
      result = shell.execOutSync('sh', '-c', `ls -TREal "${tmpDir}" 2>&1`);
      if (result.out) {
        common.printTrace(stringlib.paddingLeft(result.out, "    "));
      }
    }
  }

  const manifest = component.getManifest(tmpDir);
  const componentName = manifest.name;
  if (!componentName) {
    fs.rmrf(tmpDir);
    common.printErrorAndExit(`Error ZWEL0167E: Cannot find component name from ${componentFile} package manifest`, undefined, 167);
  }
  common.printDebug(`- Component name found as ${componentName}`);
  
  const destinationDir = pathoid.resolve(targetDir, componentName);
  const bkpDir = pathoid.resolve(targetDir, `${componentName}_zwebkp`);
  if (fs.pathExists(destinationDir)) {
    if (!upgrade) {
      fs.rmrf(tmpDir);
      common.printErrorAndExit(`Error ZWEL0155E: Component ${componentName} already exists in ${targetDir}. If you meant to upgrade this component, run the command 'zwe components upgrade' instead.`, undefined, 155);
    } else {
      if (fs.pathExists(bkpDir)) {
        fs.rmrf(bkpDir);
      }
      os.rename(destinationDir, bkpDir);
    }
  }

  common.printDebug(`- Rename temporary directory to ${componentName}.`);
  const renameResult = os.rename(tmpDir, destinationDir);
  if (renameResult < 0) {
    common.printError(`- Could not complete folder rename for ${componentName}, install failed. rc=${renameResult}`);
    if (upgrade) {
      common.printError(`- A backup of the previous ${componentName} is at ${bkpDir}`); 
    }
    return '';
  } else {
    fs.rmrf(bkpDir);
  }

  // export for next step
  std.setenv('ZWE_COMPONENTS_INSTALL_EXTRACT_COMPONENT_NAME', componentName);
  return componentName;
}
