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
import { ConfigManager } from 'Configuration';

import * as common from './common';
import * as fs from './fs';
import * as zosfs from './zos-fs';
import * as zosdataset from './zos-dataset';
import * as stringlib from './string';
import * as shell from './shell';
import * as configmgr from './configmgr';
import * as varlib from './var';
import * as fakejq from './fakejq';

const CONFIG_MGR=configmgr.CONFIG_MGR;
const ZOWE_CONFIG=configmgr.ZOWE_CONFIG;
const runtimeDirectory=ZOWE_CONFIG.zowe.runtimeDirectory;
const extensionDirectory=ZOWE_CONFIG.zowe.extensionDirectory;
const workspaceDirectory=ZOWE_CONFIG.zowe.workspaceDirectory;

//key: name of config, value: boolean on if it is cached already
const configLoadedList:any = {};


//TODO this file is full of printErrorAndExit. unreasonable?

const COMMON_SCHEMA = `${runtimeDirectory}/schemas/server-common.json`;
const MANIFEST_SCHEMA_ID = 'https://zowe.org/schemas/v2/server-component-manifest';
const MANIFEST_SCHEMAS = `${runtimeDirectory}/schemas/manifest-schema.json:${COMMON_SCHEMA}`;
const PLUGIN_DEF_SCHEMA_ID = "https://zowe.org/schemas/v2/appfw-plugin-definition";
const PLUGIN_DEF_SCHEMAS = `${runtimeDirectory}/components/app-server/schemas/plugindefinition-schema.json`;


export function getEnabledComponents(): string[] {
  let components = Object.keys(ZOWE_CONFIG.components);
  let enabled:string[] = [];
  components.forEach((key:string) => {
    if (ZOWE_CONFIG.components[key].enabled == true) {
      enabled.push(key);
    }
  });
  return enabled;
}

export function getManifestPath(componentDir: string): string|undefined {
  if (fs.fileExists(`${componentDir}/manifest.yaml`)) {
    return `${componentDir}/manifest.yaml`;
  } else if (fs.fileExists(`${componentDir}/manifest.yml`)) {
    return `${componentDir}/manifest.yml`;
  } else if (fs.fileExists(`${componentDir}/manifest.yaml`)) {
    return `${componentDir}/manifest.json`;
  }
  return undefined;
}

export function findComponentDirectory(componentId: string): string|undefined {
  if (fs.directoryExists(`${runtimeDirectory}/components/${componentId}`)) {
    return `${runtimeDirectory}/components/${componentId}`;
  } else if (extensionDirectory && fs.directoryExists(`${extensionDirectory}/${componentId}`)) {
    return `${extensionDirectory}/${componentId}`;
  }
  return undefined;
}

const pluginPointerDirectory = `${workspaceDirectory}/app-server/plugins`;
export function registerPlugin(path:string, pluginDefinition:any){
  const filePath = `${pluginPointerDirectory}/${pluginDefinition.identifier}.json`;
  if (fs.fileExists(filePath)) {
    return true;
  } else {
    let location, relativeTo;
    const index = path.indexOf(runtimeDirectory);
    if (index != -1) {
      relativeTo = "$ZWE_zowe_runtimeDirectory";
      location = filePath.substring(index);
      return fs.createFile(filePath, 0o770, JSON.stringify({
        "identifier": pluginDefinition.identifier,
        "pluginLocation": location,
        "relativeTo": relativeTo
      }, null, 2));
    } else {
      return fs.createFile(filePath, 0o770, JSON.stringify({
        "identifier": pluginDefinition.identifier,
        "pluginLocation": filePath
      }, null, 2));
    }
  }
}

function showExceptions(e: any,depth: number): void {
  let blanks = "                                                                 ";
  let subs = e.subExceptions;
  common.printError(blanks.substring(0,depth*2)+e.message);
  if (subs){
    for (const sub of subs){
      showExceptions(sub,depth+1);
    }
  }
}

export function getPluginDefinition(pluginRootPath:string) {
  const pluginDefinitionPath = `${pluginRootPath}/pluginDefinition.json`;

  if (fs.fileExists(pluginDefinitionPath)) {
    let status;
    if ((status = CONFIG_MGR.addConfig(pluginRootPath))) {
      common.printErrorAndExit(`Could not add config for ${pluginRootPath}, status=${status}`);
      return null;
    }
    
    if ((status = CONFIG_MGR.loadSchemas(pluginRootPath, PLUGIN_DEF_SCHEMAS))) {
      common.printErrorAndExit(`Could not load schemas ${PLUGIN_DEF_SCHEMAS} for plugin ${pluginRootPath}, status=${status}`);
      return null;
    }


    if ((status = CONFIG_MGR.setConfigPath(pluginRootPath, `FILE(${pluginDefinitionPath})`))) {
      common.printErrorAndExit(`Could not set config path for ${pluginDefinitionPath}, status=${status}`);
      return null;
    }
    if ((status = CONFIG_MGR.loadConfiguration(pluginRootPath))) {
      common.printErrorAndExit(`Could not load config for ${pluginDefinitionPath}, status=${status}`);
      return null;
    }

    let validation = CONFIG_MGR.validate(pluginRootPath);
    if (validation.ok){
      if (validation.exceptionTree){
        common.printError(`Validation of ${pluginDefinitionPath} against schema ${PLUGIN_DEF_SCHEMA_ID} found invalid JSON Schema data`);
        showExceptions(validation.exceptionTree, 0);
        std.exit(1);
        return null;
      } else {
        return CONFIG_MGR.getConfigData(pluginRootPath);
      }
    } else {
      common.printErrorAndExit(`Error occurred on validation of ${pluginDefinitionPath} against schema ${PLUGIN_DEF_SCHEMA_ID} `);
      return null;
    }
  } else {
    common.printErrorAndExit(`Plugin at ${pluginRootPath} has no pluginDefinition.json`);
    return null;
  }
}


export function getManifest(componentDirectory: string): any {
  let manifestPath = getManifestPath(componentDirectory);

  if (manifestPath) {
    let status;

    let manifestId = componentDirectory;
    if (configLoadedList[manifestId] === true) {
      return CONFIG_MGR.getConfigData(manifestId);
    }

    if ((status = CONFIG_MGR.addConfig(manifestId))) {
      common.printErrorAndExit(`Could not add config for ${manifestPath}, status=${status}`);
      return null;
    }

    if ((status = CONFIG_MGR.loadSchemas(manifestId, MANIFEST_SCHEMAS))) {
      common.printErrorAndExit(`Could not load schemas ${MANIFEST_SCHEMAS} for manifest ${manifestPath}, status=${status}`);
      return null;
    }

    if ((status = CONFIG_MGR.setConfigPath(manifestId, `FILE(${manifestPath})`))) {
      common.printErrorAndExit(`Could not set config path for ${manifestPath}, status=${status}`);
      return null;
    }

    if ((status = CONFIG_MGR.loadConfiguration(manifestId))) {
      common.printErrorAndExit(`Could not load config for ${manifestPath}, status=${status}`);
      return null;
    }

    let validation = CONFIG_MGR.validate(manifestId);
    if (validation.ok){
      if (validation.exceptionTree){
        common.printError(`Validation of ${manifestPath} against schema ${MANIFEST_SCHEMA_ID} found invalid JSON Schema data`);
        showExceptions(validation.exceptionTree, 0);
        std.exit(1);
        return null;
      } else {
        configLoadedList[manifestId] = true;
        return CONFIG_MGR.getConfigData(manifestId);
      }
    } else {
      common.printErrorAndExit(`Error occurred on validation of ${manifestPath} against schema ${MANIFEST_SCHEMA_ID} `);
      return null;
    }
  } else {
    common.printErrorAndExit(`Component at ${componentDirectory} has no manifest`);
    return null;
  }
}



export function validateConfigForComponent(componentId: string, manifest: any, componentDir: string, configPath: string): {path: string, name: string, contents: any}|undefined {
  return configmgr.getComponentConfig(componentId, manifest, componentDir, configPath);
}

export function detectComponentManifestEncoding(componentDir: string): number|undefined {
  const manifestPath = getManifestPath(componentDir);
  if (!manifestPath) {
    return undefined;
  }
  const encoding = zosfs.detectFileEncoding(manifestPath, 'name');
  return encoding!==-1 ? encoding : undefined;
}

export function detectIfComponentTagged(componentDir: string): boolean {
  const manifestPath = getManifestPath(componentDir);
  if (!manifestPath) {
    return false;
  }
  const encoding = zosfs.getFileEncoding(manifestPath);
  if (encoding===undefined) {
    return false;
  }
  return encoding!==0;
}

export function findAllInstalledComponents(): string {
  let components='';
  let subDirectories = fs.getSubdirectories(`${runtimeDirectory}/components`);
  if (subDirectories) {
    subDirectories.forEach((component:string)=> {
      if (getManifestPath(`${runtimeDirectory}/components/${component}`)) {
        components=`${components},${component}`;
      }
    });
  }

  if (extensionDirectory && fs.directoryExists(extensionDirectory)) {
    subDirectories = fs.getSubdirectories(extensionDirectory);
    if (subDirectories) {
      subDirectories.forEach((component: string)=> {
        if (getManifestPath(`${extensionDirectory}/${component}`)) {
          components=`${components},${component}`;  
        }
      });
    }
  }
  return components.length > 1 ? components.substring(1) : components;
}

export function findAllInstalledComponents2(): string[] {
  let components:string[] = [];
  let subDirectories = fs.getSubdirectories(`${runtimeDirectory}/components`);
  if (subDirectories) {
    subDirectories.forEach((component:string)=> {
      if (getManifestPath(`${runtimeDirectory}/components/${component}`)) {
        components.push(component);
      }
    });
  }

  if (extensionDirectory && fs.directoryExists(extensionDirectory)) {
    subDirectories = fs.getSubdirectories(extensionDirectory);
    if (subDirectories) {
      subDirectories.forEach((component: string)=> {
        if (getManifestPath(`${extensionDirectory}/${component}`)) {
          components.push(component);
        }
      });
    }
  }
  return components;
}

export function findAllEnabledComponents(): string {
  return findAllEnabledComponents2().join(',');
}

export function findAllEnabledComponents2(): string[] {
  let installedComponentsEnv=std.getenv('ZWE_INSTALLED_COMPONENTS');
  let installedComponents = installedComponentsEnv ? installedComponentsEnv.split(',') : null;
  if (!installedComponents) {
    installedComponents = findAllInstalledComponents2();
  }
  return installedComponents.filter(function(component: string) {
    let componentNameAsEnv=stringlib.sanitizeAlphanum(component);
    return std.getenv(`ZWE_components_${componentNameAsEnv}_enabled`) == 'true';
  });
}

export function findAllLaunchComponents(): string {
  return findAllLaunchComponents2().join(',');
}

export function findAllLaunchComponents2(): string[] {
  let enabledComponentsEnv=std.getenv('ZWE_ENABLED_COMPONENTS');
  let enabledComponents = enabledComponentsEnv ? enabledComponentsEnv.split(',') : null;
  if (!enabledComponents) {
    enabledComponents = findAllEnabledComponents2();
  }

  return enabledComponents.filter(function(component: string) {
    const componentDir = findComponentDirectory(component);
    if (componentDir) {
      const manifest = getManifest(componentDir);
      if (manifest && manifest.commands && manifest.commands.start) {
        return fs.fileExists(`${componentDir}/${manifest.commands.start}`);
      }
    }
    return false;
  });
}

export function processComponentApimlStaticDefinitions(componentDir: string): boolean {
  const STATIC_DEF_DIR=std.getenv('ZWE_STATIC_DEFINITIONS_DIR');
  if (!STATIC_DEF_DIR) {
    common.printError("Error: ZWE_STATIC_DEFINITIONS_DIR is required to process component definitions for API Mediation Layer.");
    return false;
  }

  const manifest = getManifest(componentDir);
  if (!manifest) {
    common.printError(`Error: manifest read or validation fail for ${componentDir}`);
    return false;
  }

  let allSucceed=true;
  const componentName = manifest.name;
  if (manifest.apimlServices && manifest.apimlServices.static) {
    let staticDefs = manifest.apimlServices.static;
    for (let i = 0; i < staticDefs.length; i++) {
      const staticDef = staticDefs[i];
      const file=staticDef.file;
      const path = `${componentDir}/${file}`
      if (!fs.fileExists(path)){
        common.printError("Error: static definition file ${file} of ${componentName} is not accessible");
        allSucceed=false;
        break;
      } else {
        common.printDebug(`Process ${componentName} service static definition file ${file}`);
        const sanitizedDefName=stringlib.sanitizeAlphanum(file);

        const contents = xplatform.loadFileUTF8(path,xplatform.AUTO_DETECT);
        if (contents) {
          const resolvedContents = varlib.resolveShellTemplate(contents);

          const zweCliParameterHaInstance=std.getenv("ZWE_CLI_PARAMETER_HA_INSTANCE");
          //discovery static code requires specifically .yml. Not .yaml
          const outPath=`${STATIC_DEF_DIR}/${componentName}.${sanitizedDefName}.${zweCliParameterHaInstance}.yml`;

          common.printDebug(`- writing ${outPath}`);

          //discovery static code seems to be ascii regardless of platform. on zos it is tagged ebcdic even when its ascii?
          //i'm writing the file out in this way below because i know it ends up in the right encoding when doing this.
          let errorObj;
          let fileReturn = std.open(outPath, 'w', errorObj);
          if (fileReturn && !errorObj) {
            fileReturn.puts(resolvedContents);
            fileReturn.close();
            shell.execSync(`chmod`, `770`, outPath);
          } else {
            common.printError(`Could not write static definition file ${outPath}, errobj=`+errorObj);
          }
        }
      }
    }
  }
  return allSucceed;
}

/*
 Parse and process manifest App Framework Plugin (appfwPlugins) definitions

 The supported manifest entry is ".appfwPlugins". All plugins
 defined will be passed to install-app.sh for proper installation.
*/
export function testOrSetPcBit(path: string): boolean {
  if (!hasPCBit(path)) {
    common.printError("Plugin ZSS API not program controlled. Attempting to add PC bit.");
    zos.changeExtAttr(path, zos.EXTATTR_PROGCTL, true);
    const success = hasPCBit(path);
    if (!success) {
      common.printErrorAndExit(`PC bit not set. This must be set such as by executing 'extattr +p ${path}' as a user with sufficient privilege.`);
    }
    return success;
  } else {
    return true;
  }
}

export function hasPCBit(path: string): boolean {
  const returnArray = zos.zstat(path);
  if (!returnArray[1]) { //no error
    return returnArray[0].extattrs == zos.EXTATTR_PROGCTL
  } else {
    if (returnArray[1] != std.Error.ENOENT) {
      common.printError(`hasPCBit path=${path}, err=${returnArray[1]}`);
    }
    return false;
  }
}


export function checkZssPcBit(appfwPluginPath: string): void {
  const pluginDefinition = getPluginDefinition(appfwPluginPath);
  if (pluginDefinition) {
    if (pluginDefinition.dataServices) {
      common.printDebug(`Checking ZSS services in plugin path=${appfwPluginPath}`);
      pluginDefinition.dataServices.forEach(function(service: any){
        if (service.type == 'service') {
          if (service.libraryName31) {
            testOrSetPcBit(`${appfwPluginPath}/lib/${service.libraryName31}`);
          }
          if (service.libraryName64) {
            testOrSetPcBit(`${appfwPluginPath}/lib/${service.libraryName64}`);
          }
          if (service.libraryName) {
            testOrSetPcBit(`${appfwPluginPath}/lib/${service.libraryName}`);
          }
        }
      });
    }
  } else {
    common.printErrorAndExit(`Skipping ZSS PC bit check of plugin at ${appfwPluginPath} due to pluginDefinition missing or invalid`);
  }
}

export function processZssPluginInstall(componentDir: string): void {
  if (os.platform == 'zos') {
    common.printDebug(`- Checking for zss plugins and verifying them`);
    const manifest = getManifest(componentDir);
    if (manifest && manifest.appfwPlugins) {
      manifest.appfwPlugins.forEach(function(appfwPlugin: any) {
        const path = appfwPlugin.path;
        checkZssPcBit(`${componentDir}/${path}`);
      });
    }
  }
}

/*
  Example manifest of a zis plugin component

  name: zis-plugin
  id: org.zowe.zis.plugin
  commands:
    start: bin/start.sh
    configure: bin/configure.sh
  zisPlugins:
    - id: "hello.zis.plugin"
      path: "/zisServer"
  schemas:
  configs: schemas/trivial-schema.json


  Example of a zowe.yaml used for zis plugin install

zowe:
  setup:
    dataset:
      prefix: "MVS.DATASET"
      proclib: "ROCKET.USER.PROCLIB"
      parmlib: "MVS.DATASET.CUST.PARMLIB"
      parmlibMembers:
        zis: "ZWESIP00"
      jcllib: "MVS.DATASET.CUST.JCLLIB"
      authLoadlib: "MVS.DATASET.SZWEAUTH"
      authPluginLib: "MVS.DATASET.CUST.ZWESAPL"
    zis:
      parmlib:
        keys:
          beep.boop: "list"
  runtimeDirectory: "/u/user/zowe/test/zistest"
  logDirectory: "/u/user/zowe/inst/zistest/logs"
  workspaceDirectory: "/u/user/zowe/inst/zistest/workspace"
  extensionDirectory: "/u/user/zowe/inst/zistest/extensions"

*/
export function processZisPluginInstall(componentDir: string): void {
  if (os.platform == 'zos') {
    common.printTrace("- Checking for zis plugins and verifying them");

    const manifest = getManifest(componentDir);

    if (manifest.zisPlugins) {
      if (!ZOWE_CONFIG.zowe?.setup?.dataset || !ZOWE_CONFIG.zowe.setup.dataset.authPluginLib
        || !ZOWE_CONFIG.zowe.setup.dataset.parmlib || !ZOWE_CONFIG.zowe.setup.dataset.parmlibMembers?.zis) {
        common.printError(`One or more configuration parameters for ZIS plugin install are missing. Define zowe.setup.dataset to have authPluginLib, parmlib, and parmlibMembers entries.`);
        std.exit(1);
      }
      manifest.zisPlugins.forEach((zisPlugin: {id: string, path: string})=> {
        common.printTrace(`Attempting to install ZIS plugin ${zisPlugin.id} at ${zisPlugin.path}`);
        const rc = zisPluginInstall(zisPlugin.path, ZOWE_CONFIG.zowe.setup.dataset.authPluginLib,
                                    ZOWE_CONFIG.zowe.setup.dataset.parmlib, ZOWE_CONFIG.zowe.setup.dataset.parmlibMembers.zis,
                                    zisPlugin.id, componentDir,
                                    ZOWE_CONFIG.zowe?.setup?.zis?.parmlib?.keys || {});
        if (rc) {
          common.printMessage(`Failed to install ZIS plugin: ${zisPlugin.id}`);
          std.exit(1);
        }
      });
    }
  }
}

function getKeyOfString(input: string): string {
  const index = input.indexOf('=');
  return input.substring(0,index == -1 ? undefined : index);
}

function getValueOfString(input: string): string {
  const index = input.indexOf('=');
  return index == -1 ? input : input.substring(index+1);
}

function addKeyValueAtEndOfString(pair: string, input: string): string|undefined {
  const key=getKeyOfString(pair);
  const value=getValueOfString(pair);
  const resolvedValue=resolveEnvParameter(value); // Check for env variable substitution
  common.printDebug(`Resolved parmlib value for ${key}. '${value}' became '${resolvedValue}'`);
  // Check if we recevied a non-empty value for the key (if the value has been
  // defined using an environmental variable).
  if (resolvedValue == "VALUE_NOT_FOUND") {
    common.printError(`Error ZWEL0203E: Env value in key-value pair ${pair} has not been defined.`);
    return undefined;
  }
  input+='\n'+`${key}=${resolvedValue}`;
  return input;
}

export function zisPluginInstall(pluginPath: string, zisPluginlib: string, zisParmlib: string,
                                 zisParmlibMember: string, pluginId: string, componentDir: string, parmlibKeys: string): number {
  const parmlibMemberAsUnixFile=fs.createTmpFile(zisParmlibMember);

  zosfs.copyMvsToUss(`${zisParmlib}(${zisParmlibMember})`, parmlibMemberAsUnixFile);
  let parmlibContents = xplatform.loadFileUTF8(parmlibMemberAsUnixFile, xplatform.AUTO_DETECT);
  common.printDebug(`Parmlib starts as \n${parmlibContents}`);
  let parmlibLines = parmlibContents.split('\n');
  
  let changed=false;

  const basePath=`${componentDir}/${pluginPath}`;
  const samplibPath=`${basePath}/samplib`;
  const loadlibPath=`${basePath}/loadlib`;

  if (fs.directoryExists(basePath)) {
    if (fs.directoryExists(loadlibPath) && fs.directoryExists(samplibPath)) {
      const modules = fs.getFilesInDirectory(loadlibPath) || [];
      for (let i = 0; i < modules.length; i++) {
        const module = modules[i];
        const rc = zosdataset.copyToDataset(`${loadlibPath}/${module}`, zisPluginlib, "", true);
        if (rc != 0) {
          common.printError(`Error ZWEL0200E: Failed to copy USS file ${loadlibPath}/${module} to MVS data set ${zisPluginlib}.`);
          return 200;
        }
      }
      const files = fs.getFilesInDirectory(samplibPath)
      for (let i = 0; i < files.length; i++) {
        const params = files[i];
        if (!fs.fileExists(`${samplibPath}/${params}`)) {
          common.printError(`Error ZWEL0201E: File ${samplibPath}/${params} does not exist.`);
          return 201;
        }
        const contents = xplatform.loadFileUTF8(`${samplibPath}/${params}`, xplatform.AUTO_DETECT);
        contents.split('\n').forEach((samplibKeyvalue:string)=> {
          const prefix=samplibKeyvalue.substring(0,2);
          if (!(prefix == '//' || prefix == '* ' || prefix == '')) {
            common.printDebug(`Checking existing parmlib line ${samplibKeyvalue} to see if it is in plugin parmlib lines`);
            let lineIndex = parmlibLines.indexOf(samplibKeyvalue);
            if (lineIndex != -1) {
              common.printDebug(`The key-value pair ${samplibKeyvalue} is being skipped because it's already there and hasn't changed (index ${lineIndex}).`);
            } else {
              let result = updateUssParmlibKeyValue(samplibKeyvalue, parmlibKeys, parmlibContents);
              if (result.error) {
                common.printMessage(`Failed to install ZIS plugin: ${pluginId}`);
                std.exit(1);
              } else if (result.changed) {
                parmlibContents = result.contents;
                parmlibLines = parmlibContents.split('\n');
                changed = true;
              }
            }
          }
        });
      }
      common.printMessage(`Successfully installed ZIS plugin: ${pluginId}`);
    } else {
      common.printError(`Directory ${loadlibPath} or ${samplibPath} does not exist`);
      return 1;
    }
  } else {
    common.printError(`Error ZWEL0201E: Directory ${basePath} does not exist`);
    return 201;
  }

  if (changed) {
    common.printDebug(`Parmlib modified, writing as \n${parmlibContents}`);
    xplatform.storeFileUTF8(parmlibMemberAsUnixFile, xplatform.AUTO_DETECT, parmlibContents);
    zosdataset.copyToDataset(parmlibMemberAsUnixFile, `${zisParmlib}(${zisParmlibMember})`, "", true);
  }
  return 0;
}

/*
  Used to write a plugin's parmlib entries into the zis parmlib.

  Consider a plugin parmlib file:

  beep.boop=one,two

  thing1.thing2.thing3=$TERM

  foo.bar.baz=1


  ... plugin parmlib keys are '.' seperated, with a '=' between key and value.
  values can be strings or $env vars, and so the line should be evaluated before
  putting into the zis parmlib.
  
 */
function updateUssParmlibKeyValue(samplibKeyValue: string, parmlibKeys: string, contents: string): { error?: number, changed?: boolean, contents?: string } {
  const samplibKey = getKeyOfString(samplibKeyValue);
  let isChanged: boolean = false;
  if (!samplibKey) {
    common.printError(`Error ZWEL0202E: Unable to find samplib key for ${samplibKeyValue}.`);
    return { error: 202 };
  }

  let newContents = contents;
  let lines = contents.split('\n');

  // In the case of a key not being there, an empty string will be returned.
  const included = contents.includes(samplibKey);
  let num: number;
  if (included) {
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].includes(samplibKey)) {
        num = i;
        break;
      }
    }
  }

  if (num) {
    const replacer = new RegExp('\\.', 'g');
    const parsedParmlibKeys = JSON.stringify(parmlibKeys).replace(replacer, '_'); // replace . with _ in keyname for working key search
    const parsedSamplibKey = samplibKey.replace(replacer, '_'); // replace . with _ in keyname for working key search
    const configSamplibKeyValue = fakejq.jqget(JSON.parse(parsedParmlibKeys), `.${parsedSamplibKey}`);
    if (configSamplibKeyValue == "list") {
      // The key is comma separated list
      const parmlibKeyValue = lines.length > num ? lines[num] : contents;
      const parmlibValue=getValueOfString(parmlibKeyValue);
      const samplibValue=getValueOfString(samplibKeyValue);
      if (!parmlibValue.includes(samplibValue)) {
        const newParmlibKeyValue=`${samplibKey}=${parmlibValue},${samplibValue}`;
        common.printDebug(`Replacing parmlib key ${samplibKey} (list). Old value=${parmlibValue}. New line = ${newParmlibKeyValue}`);
        lines.splice(num, 1);
        newContents = lines.join('\n');
        newContents = addKeyValueAtEndOfString(newParmlibKeyValue, newContents);
        isChanged = true;
      } else {
        common.printDebug(`Skipping parmlib key ${samplibKey} because value did not change`);
      }
    } else {
      // The key is not special and the value is different.
      lines.splice(num, 1);
      newContents = lines.join('\n');
      common.printDebug(`Replacing parmlib key ${samplibKey}. New line = ${samplibKeyValue}`);
      newContents = addKeyValueAtEndOfString(samplibKeyValue, newContents);
      isChanged = true;
    }
  } else {
    common.printDebug(`Adding new parmlib key ${samplibKey}. New line = ${samplibKeyValue}`);
    // The key doesn't exist. Just add the key-value pair to the end of the file.
    newContents = addKeyValueAtEndOfString(samplibKeyValue, contents);
    isChanged = true;
  }
  return { changed: isChanged, contents: newContents };
}

// Try to resolve values that are defined using
// environmental variables, otherwise return
// the original value - borrowed from ZSS
//
// @param string   value
// Returns:
//   * If an env variable is provided, its value
//     is returned on success
//   * If an env variable is provided and
//     the variable is not defined,
//     string VALUE_NOT_FOUND is returned
//   * The original value is returned
function resolveEnvParameter(input: string): string {
  return varlib.resolveShellTemplate(input);
}



export function processComponentAppfwPlugin(componentDir: string): boolean {
  const manifest = getManifest(componentDir);
  if (manifest && manifest.appfwPlugins) {
    for (let i = 0; i < manifest.appfwPlugins.length; i++) {
      const appfwPlugin = manifest.appfwPlugins[i];
      const fullPath = `${componentDir}/${appfwPlugin.path}`;
      if (!fs.fileExists(`${fullPath}/pluginDefinition.json`)) {
        common.printError(`App Framework plugin directory ${fullPath} does not have pluginDefinition.json`);
        return false;
      }
      
      if (os.platform != 'zos') {
        const pluginDefinition = getPluginDefinition(fullPath);
        if (pluginDefinition && pluginDefinition.identifier) {
          const pluginDirsPath=`${workspaceDirectory}/app-server/pluginDirs`;
          let rc = fs.mkdirp(`${pluginDirsPath}/${pluginDefinition.identifier}`, 0o770);
          if (rc) {
            common.printError(`Plugin registration failed because cannot make directory = ${pluginDirsPath}/${pluginDefinition.identifier}`);
          }
          fs.cpr(`${fullPath}/.`, `${pluginDirsPath}/${pluginDefinition.identifier}`);

          return registerPlugin(fullPath, pluginDefinition);
        } else {
          common.printError(`Cannot read identifier from App Framework plugin ${fullPath}/pluginDefinition.json`);
          return false;
        }
      }
    }
  }
  return true;
}

/*
 Parse and process manifest Gateway Shared Libs (gatewaySharedLibs) definitions

 The supported manifest entry is ".gatewaySharedLibs". All shared libs
 defined will be passed to install-app.sh for proper installation.
*/
export function processComponentGatewaySharedLibs(componentDir: string): boolean {
  const gatewaySharedLibs = std.getenv('ZWE_GATEWAY_SHARED_LIBS');
  fs.mkdirp(gatewaySharedLibs, 0o770);

  const manifest = getManifest(componentDir);
  let pluginName;
  let gatewaySharedLibsWorkspacePath:string|undefined;
  
  if (manifest && manifest.gatewaySharedLibs) {
    for (let i = 0; i < manifest.gatewaySharedLibs.length; i++) {
      const gatewaySharedLibsDef = manifest.gatewaySharedLibs[i];
      const fileOrDir=`${componentDir}/${gatewaySharedLibsDef}`;
      if (!pluginName) {
        pluginName = manifest.name;
        if (!pluginName) {
          common.printError(`Cannot read name from the plugin ${componentDir}`);
          return false;
        }
        gatewaySharedLibsWorkspacePath = `${gatewaySharedLibs}/${pluginName}`;
        fs.mkdirp(gatewaySharedLibsWorkspacePath, 0o770);
      }

      if (!gatewaySharedLibsWorkspacePath){
        common.printError("Unexpected error: did not find gatewaySharedLibsWorkspacePath");
        return false;
      }

      const manifestPath = getManifestPath(componentDir);
      if (manifestPath){
        fs.cp(manifestPath, gatewaySharedLibsWorkspacePath);
      }

      if (fs.fileExists(fileOrDir)) {
        fs.cp(fileOrDir, gatewaySharedLibsWorkspacePath);
      } else if (fs.directoryExists(fileOrDir)) {
        fs.cp(`${fileOrDir}/\*`, gatewaySharedLibsWorkspacePath);
      } else {
        common.printError(`Gateway shared libs directory ${fileOrDir} is not accessible`);
        return false;
      }
    }
  }
  return true;
}


/*
 Parse and process manifest Discovery Shared Libs (discoverySharedLibs) definitions

 The supported manifest entry is ".discoverySharedLibs". All shared libs
 defined will be passed to install-app.sh for proper installation.
*/
export function processComponentDiscoverySharedLibs(componentDir: string): boolean {
  const discoverySharedLibs = std.getenv('ZWE_DISCOVERY_SHARED_LIBS');
  fs.mkdirp(discoverySharedLibs, 0o770);

  const manifest = getManifest(componentDir);
  let pluginName;
  let discoverySharedLibsWorkspacePath;
  
  if (manifest && manifest.discoverySharedLibs) {
    for (let i = 0; i < manifest.discoverySharedLibs.length; i++) {
      const discoverySharedLibsDef = manifest.discoverySharedLibs[i];
      const fileOrDir=`${componentDir}/${discoverySharedLibsDef}`;
      if (!pluginName) {
        pluginName = manifest.name;
        if (!pluginName) {
          common.printError(`Cannot read name from the plugin ${componentDir}`);
          return false;
        }
        discoverySharedLibsWorkspacePath = `${discoverySharedLibs}/${pluginName}`;
        fs.mkdirp(discoverySharedLibsWorkspacePath, 0o770);
      }

      if (!discoverySharedLibsWorkspacePath){
        common.printError('Unexpected error: did not find discoverySharedLibsWorkspacePath');
        return false;
      }

      const manifestPath = getManifestPath(componentDir);
      if (manifestPath) {
        fs.cp(manifestPath, discoverySharedLibsWorkspacePath);
      }

      if (fs.fileExists(fileOrDir)) {
        fs.cp(fileOrDir, discoverySharedLibsWorkspacePath);
      } else if (fs.directoryExists(fileOrDir)) {
        fs.cp(`${fileOrDir}/\*`, discoverySharedLibsWorkspacePath);
      } else {
        common.printError(`Discovery shared libs directory ${fileOrDir} is not accessible`);
        return false;
      }
    }
  }
  return true;
}
/*
const gatewayHost = std.getenv('ZWE_GATEWAY_HOST');
const haInstanceHostname = std.getenv('ZWE_haInstance_hostname');
const catalogPort = Number(std.getenv('ZWE_components_api_catalog_port'));
const zoweCertificatePemKey = std.getenv('ZWE_zowe_certificate_pem_key');
const zoweCertificatePemCertificate = std.getenv('ZWE_zowe_certificate_pem_certificate');
const zoweCertificatePemCertificateAuthorities = std.getenv('ZWE_zowe_certificate_pem_certificateAuthorities');
//TODO implement refreshStaticRegistration

export function refreshStaticRegistration(apimlcatalogHost: string=gatewayHost, apimlcatalogPort: number= catalogPort,
                                   authKey: string=zoweCertificatePemKey, authCert: string=zoweCertificatePemCertificate,
                                   caCert: string=zoweCertificatePemCertificateAuthorities): number{
  if (!apimlcatalogHost) {
    if (haInstanceHostname) {
      apimlcatalogHost = haInstanceHostname;
    } else {
      apimlcatalogHost = 'localhost';
    }
  }
}
*/
