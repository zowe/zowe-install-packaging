/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as extract from './extract/index';
import * as installHook from './process-hook/index';
import * as componentEnable from '../enable/index';
import * as common from '../../../libs/common';
import * as fs from '../../../libs/fs';
import * as config from '../../../libs/config';
import * as componentlib from '../../../libs/component';
import { HandlerCaller, getHandler, getRegistry } from '../handlerutils';
import * as xplatform from 'xplatform';
import * as zosdataset from '../../../libs/zos-dataset';
import * as zosfs from '../../../libs/zos-fs';

export function execute(componentFile: string, autoEncoding?:string, skipEnable?:boolean, handler?: string, registry?: string, dryRun?: boolean, upgrade?: boolean, stepLibs?: string) {
  if (!fs.fileExists(componentFile) && !fs.directoryExists(componentFile)) {
    common.requireZoweYaml();
    if (componentFile && !upgrade) {
      const componentDir = componentlib.findComponentDirectory(componentFile);
      
      if (componentDir) {
        common.printMessage("Already installed");
        return;
      }
    }
    //We only call the registry handler if given an argument thats not a path. If the handler returns null, we must fail because there's nothing left to do.
    componentFile = handlerInstall(componentFile, handler, registry, dryRun, upgrade);

    if (componentFile==='null' && !dryRun) {
      common.printErrorAndExit("Error ZWEL0304E: Handler install failure, cannot continue.", undefined, 304);
    }
  }

  //if upgrade with 'all', or if a component had dependencies, there could be a list of things to act upon here
  // TODO this does not allow multi install from package due to the initial existence check, but maybe we could enable that later.
  const components = componentFile.split(',');

  components.forEach((componentFile: string) => {
    if (componentFile==='null') {
      //TODO wish more could be said here
      common.printError("Error ZWEL0305E: Could not find one of the components' directories.");
    } else {
      common.printMessage(`Installing file or folder=${componentFile}`);
      if (!dryRun) {
        extract.execute(componentFile, autoEncoding, upgrade);
        
        // ZWE_COMPONENTS_INSTALL_EXTRACT_COMPONENT_NAME should be set after extract step
        const componentName = std.getenv('ZWE_COMPONENTS_INSTALL_EXTRACT_COMPONENT_NAME');
        if (componentName) {
          installHook.execute(componentName);
        } else {
          common.printErrorAndExit("Error ZWEL0156E: Component name is not initialized after extract step.", undefined, 156);
        }

        if (!skipEnable) {
          componentEnable.execute(componentName);
        }

        // Adding new entries to the steplib sections of zis & aux stcs
        if (stepLibs) {
          updateSTCS(stepLibs);
        }
      }
    }
  });
}
function updateSTCS(stepLibs: string)
{
  const ZOWE_CONFIG=config.getZoweConfig();
  const proclib = ZOWE_CONFIG.zowe.setup?.dataset?.proclib;
  const zisMember = ZOWE_CONFIG.zowe.setup?.security?.stcs?.zis;
  const auxMember = ZOWE_CONFIG.zowe.setup?.security?.stcs?.aux;

  // process step arguements with multiple checks, eg Regex, duplicates etc
  const stepLibEntries = processSteplibArgs(stepLibs);

  // Update the ZIS STC
  if (zosdataset.isDatasetExists(`${proclib}(${zisMember})`)) {
    updateStcSteplibEntries(proclib, zisMember, stepLibEntries);
  }
  // Update the AUX STC
  if (zosdataset.isDatasetExists(`${proclib}(${auxMember})`)) {
    updateStcSteplibEntries(proclib, auxMember, stepLibEntries);
  }
}

function updateStcSteplibEntries(proclib: string, member: string, stepLibEntries: string[]): boolean {
  const ZOWE_CONFIG=config.getZoweConfig();
  const jclLib = ZOWE_CONFIG.zowe.setup.dataset.jcllib;
  const prefix = ZOWE_CONFIG.zowe.setup.dataset.prefix;
  let update = false;

  // 1. create temporary Unix file
  const proclibMemberAsUnixFile = fs.createTmpFile(`${proclib}`);
  zosfs.copyMvsToUss(`${proclib}(${member})`, proclibMemberAsUnixFile);

  // 2. Get the updated content
  const updatedContent = updateStepLib(proclibMemberAsUnixFile, stepLibEntries);
  //common.printMessage(`GKP:updated content`);
  //common.printMessage(updatedContent);

  // 3. store the updated content in the same temporary Unix file
  let rc = xplatform.storeFileUTF8(proclibMemberAsUnixFile, xplatform.AUTO_DETECT, updatedContent);
  if(!rc) {
    // 4. Copy the contents from the temporary file into a temporary dataset
    const tmpDataset = zosdataset.createDatasetTmpMember(jclLib);
    rc = zosdataset.copyToDataset(proclibMemberAsUnixFile, `${jclLib}(${tmpDataset})`, "", true);
    if (rc) {
      common.printError(`Error ZWEL0200E: Failed to copy USS file ${proclibMemberAsUnixFile} to MVS data set ${tmpDataset}.`);
    }
    else {
      // 5. Copy the dataset using PREFIX.SZWEEXEC(ZWEMCOPY)
      rc = zosdataset.datasetCopyToDataset(prefix, `${jclLib}(${tmpDataset})`, `${proclib}(${member})`, true);
      if (rc) {
        common.printError(`Copy of temporary to dataset to ${proclib}(${member}) did not happen`);
      }
      else {
        update = true;
        common.printMessage(`${proclib}(${member}) updated successfully with new stepLib entries`);
      }
    }
  }
  else {
    common.printError(`Error: Could not store updated contents in tmp unix file ${proclibMemberAsUnixFile}.`);
  }
  return update;
}

function processSteplibArgs(inputArgs: string): string[] {
  return Array.from(
    new Set(
      inputArgs
        .split(",")
        .map(word => word.trim())
        .map(word => word.toUpperCase())
        .filter(word => word !== "")
        .filter(word => regexCheck(word) && word.length <= 44)
        .filter(word => zosdataset.isDatasetExists(word))
    )
  );
}

const regexCheck = (word: string): boolean => {
  const datasetRegex = /^([A-Z\$\#\@]){1}([A-Z0-9\$\#\@\-]){0,7}(\.([A-Z\$\#\@]){1}([A-Z0-9\$\#\@\-]){0,7}){0,11}$/
  return datasetRegex.test(word);
}

// Goes through the steplib section and adds entries, skipping blank lines and commented lines. However if an entry is commented and is
// part of new list of entries, then we uncomment that entry/line.
function updateStepLib(procLibfile: string, newStepLibEntries:  string[]) : any {
  let procJcl = xplatform.loadFileUTF8(procLibfile, xplatform.AUTO_DETECT);
  let lines = procJcl.split("\n");

  // find index of start of STEPLIB section
  let stepLibIndex = lines.findIndex((line => line.trim().startsWith('//STEPLIB')));
  let i = stepLibIndex+1;
  // go through the STEPLIB section
  while(i < lines.length)
  {
    let line = lines[i].trim();
    if (line.startsWith('//') && !line.startsWith('// ') && !line.startsWith('//*')) {
          // end of STEPLIB section, break and add remaining entries
          break;
    }
    else {
        // extract the existing STEPLIB entry and check if it is in the new list, if so remove it from the list to avoid duplicates
        // or if it is commented then uncomment it
        let dsnString =  line.match(/DSNAME=([\w.@#$-]+)/);
        if(dsnString) {
          let removeIndex = newStepLibEntries.indexOf(dsnString[1]);
          if (removeIndex !== -1) {
            // Check to see if it is commented
            if (line.startsWith('//*')) {
              lines.splice(i, 1); // remove the line
              lines.splice(i, 0, `//         DD   DSNAME=${dsnString[1]},DISP=SHR`); // add the uncommented version
            }
            // remove entry to avoid duplicates
            newStepLibEntries.splice(removeIndex, 1);
          }
        }
    }
    i++;
  }
  // adding the remaining of entries at the end of STEPLIB section
  newStepLibEntries.reverse().forEach((newEntry) => {
    lines.splice(i, 0, `//         DD   DSNAME=${newEntry},DISP=SHR`);
  });

  return lines.join("\n");
}

function handlerInstall(component: string, handler?: string, registry?: string, dryRun?: boolean, upgrade?: boolean): string {
  const ZOWE_CONFIG=config.getZoweConfig();

  if (component === 'all' && !upgrade) {
    common.printErrorAndExit("Error ZWEL0314E: Cannot install with component=all. This option only exists for upgrade.", undefined, 314);
  } else if (component === 'all') {
    const allExtensions = componentlib.findAllInstalledComponents2().filter(component=> componentlib.findComponentDirectory(component).startsWith(ZOWE_CONFIG.zowe.extensionDirectory+'/')).join(',');
    if (allExtensions) {
      //all extensions doesnt mean every one exists from this handler. handler must check them.
      component = allExtensions;
    }
  }

  handler = getHandler(handler);
  if (!handler) {
    common.printErrorAndExit("Error ZWEL0315E: Handler (-handler or zowe.extensionRegistry.defaultHandler) required but not specified.", undefined, 255);
  }
  registry = getRegistry(handler, registry);  
  const handlerCaller = new HandlerCaller(handler, registry);

  return upgrade ? handlerCaller.upgrade(component, dryRun) : handlerCaller.install(component, dryRun);
}
