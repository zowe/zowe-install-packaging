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

import * as fs from '../../../../libs/fs';
import * as common from '../../../../libs/common';
import * as stringlib from '../../../../libs/string';
import * as shell from '../../../../libs/shell';
import * as config from '../../../../libs/config';
import * as component from '../../../../libs/component';
import * as java from '../../../../libs/java';
import { PathAPI as pathoid } from '../../../../libs/pathoid';


const COMMAND_NAME = `zwe-components-install-extract`;

//TODO does this handle componentFile relative paths correctly or not
export function execute(componentFile: string, autoEncoding?: string, upgrade?: boolean, dryRun?: boolean): string|undefined {
  //////////////////////////////////////////////////////////////
  // Constants
  const pwd = std.getenv('ZWE_PWD');
  const moduleFileShort=pathoid.basename(componentFile);
  const tmp_ext_dir='tmp_'+moduleFileShort; //TODO this is a hack about getManifest() caching result per directory. The caching could be avoided by versioning, need to implement in component.ts later...
  const ZOWE_CONFIG=config.getZoweConfig();
  
  //////////////////////////////////////////////////////////////
  common.requireZoweYaml();
  let result;
  let rc:number;  
  
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
    common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `zowe.extensionDirectory (${targetDir}) does not exist and will be created`);
    if (!dryRun) {
      fs.mkdirp(targetDir);
      if (!fs.directoryExists(targetDir)) {
        common.printErrorAndExit(`Error ZWEL0139E: Failed to create directory ${targetDir}.`, undefined, 139);
      }
    }
  }

  componentFile = stringlib.removeTrailingSlash(fs.convertToAbsolutePath(componentFile) as string);

  common.printDebug(`Component path=${componentFile}`);
  common.printDebug(`Temporary target directory=${tmpDir}`);

  //////////////////////////////////////////////////////////////
  // clean up
  if (targetDir=='/') {
    common.printErrorAndExit("Error ZWEL0153E: Cannot install Zowe component to system root directory.", undefined, 153);
  }
  if (!tmpDir) {
    common.printErrorAndExit( "Error ZWEL0154E: Temporary directory is empty.", undefined, 154);
  }

  if (!dryRun) {
    fs.rmrf(tmpDir);
  }
  
  common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `Installing ${moduleFileShort}`);

  let dryRunDir;
  // if input is a directory, use symlink to add to zowe
  if (fs.directoryExists(componentFile)) {
    dryRunDir = componentFile;
    common.printMessage(`- Module ${componentFile} is a directory`);
    common.printMessage(`- Creating symbolic link from it to ${tmpDir}`);
    if (!dryRun) {
      rc = os.symlink(componentFile, tmpDir);
      if (rc) {
        common.printErrorAndExit(`Error ZWEL0204E: Symlink creation failure, error=${rc}`, undefined, 204);
      }
    }
  // otherwise, extract it.
  } else if (fs.fileExists(componentFile) || dryRun) {
    // create temporary directory to lay down extension files in
    fs.mkdirp(tmpDir);
    
    common.printDebug(`- Extract file ${moduleFileShort} to temporary directory.`);

    let command: string;

    // we can extract even if extensions are in upper case
    let componentFileLower = componentFile.toLowerCase();
    if (componentFileLower.endsWith('.pax')) {
      command = `cd ${tmpDir} && pax -ppx -rf ${componentFile}`;
    } else if (componentFileLower.endsWith('.pax.z')) {
      command = `cd ${tmpDir} && pax -ppx -X -rf ${componentFile}`;
    } else if (componentFileLower.endsWith('.zip')) {
      java.requireJava();
      command = `cd ${tmpDir} && jar xf ${componentFile}`;
    } else if (componentFileLower.endsWith('.tar')) {
      command = `_CEE_RUNOPTS="FILETAG() POSIX(ON)" cd ${tmpDir} && pax -x tar -rf "${componentFile}"`;
    } else {
      common.printErrorAndExit(`Error ZWEL0318E File extension invalid. Supported file extensions: .pax, .pax.z, .tar, .zip`, undefined, 318);
    }

    common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `- Running command ${command}`);
    if (!dryRun) {
      result = shell.execSync('sh', '-c', command);
      if (result.rc) {
        common.printError(`Extract completed with rc=${result.rc}`);
      }
      common.printTrace("  * List extracted files:");
      result = shell.execOutSync('sh', '-c', `cd ${tmpDir} && ls -la 2>&1`);
      common.printTrace(stringlib.paddingLeft(result.out, "    "));
    }

  } else {
    common.printErrorAndExit(`Error ZWEL0313E: Cannot find component file ${componentFile}.`, undefined, 313);
  }

  let manifestDir = dryRun ? dryRunDir ? dryRunDir : undefined : tmpDir;

  // tag files if requested. only valid for zos
  if (os.platform == 'zos') {

    let manifestEncoding:number;
    if (manifestDir) {
      manifestEncoding = component.detectComponentManifestEncoding(manifestDir);
    }
    common.printDebug(`- Requested auto_encoding=${autoEncoding}, component manifest encoding is ${manifestEncoding == undefined && dryRun ? 'unknown (dry run)' : manifestEncoding}.`);
    //the autotag script we have is for tagging when files are ascii, so we assume tagging cant be done unless ascii
    let autotag="no";

    if (manifestEncoding==819 && manifestDir) {
      const isTagged=component.detectIfComponentTagged(manifestDir);
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
      common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, "- Automatically tag files");
      let command = `"${ZOWE_CONFIG.zowe.runtimeDirectory}/bin/utils/tag-files.sh" "${tmpDir}" 2>&1`;
      common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `- Running command ${command}`);

      if (!dryRun) {
        result = shell.execOutSync('sh', '-c', command);
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
  }

  if ((dryRun && manifestDir) || !dryRun) {
    const manifest = component.getManifest(manifestDir);
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
        if (!dryRun) {
          common.printDebug(`Cleanup, removing "${tmpDir}"`);
          fs.rmrf(tmpDir);
        }
        common.printErrorAndExit(`Error ZWEL0155E: Component ${componentName} already exists in ${targetDir}. If you meant to upgrade this component, run the command 'zwe components upgrade' instead.`, undefined, 155);
      } else {
        common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `Creating backup of upgraded component`);
        if (fs.pathExists(bkpDir)) {
          common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `- Removing older backup, "${bkpDir}"`);
          if (!dryRun) {
            fs.rmrf(bkpDir);
          }
        }
        common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `- Renaming "${destinationDir}" to backup "${bkpDir}"`);
        if (!dryRun) {
          os.rename(destinationDir, bkpDir);
        }
      }
    }

    // extract complete, commit tmp dir as final dir
    common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `- Completing extract by renaming "${tmpDir}" to "${destinationDir}".`);
    if (!dryRun) {
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
    }

    // export for next step
    std.setenv('ZWE_COMPONENTS_INSTALL_EXTRACT_COMPONENT_NAME', componentName);
    return componentName;
  }
  return undefined;
}
