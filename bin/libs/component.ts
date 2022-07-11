/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as os from 'os';
import * as zos from 'zos';
import * as xplatform from 'xplatform';
import { ConfigManager } from 'Configuration';

import * as common from './common';
import * as fs from './fs';
import * as zosfs from './zos-fs';
import * as stringlib from './string';
import * as shell from './shell';
import * as configmgr from './configmgr';

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

/* 
${var#Pattern}, ${var##Pattern}

    ${var#Pattern} Remove from $var the shortest part of $Pattern that matches the front end of $var.

    ${var##Pattern} Remove from $var the longest part of $Pattern that matches the front end of $var. 

*/

function resolveShellVariable(previousKey: string, currentKey: string, currentValue: string|undefined, modifier: string): string|undefined {
  switch (modifier) {
  //${parameter-default}, ${parameter:-default}
  //  If parameter not set, use default.
  case '-': {
    return std.getenv(currentKey);
  }
  //${parameter+alt_value}, ${parameter:+alt_value}
  //  If parameter set, use alt_value, else use null string.
  case '+': {
    return std.getenv(previousKey) ? std.getenv(currentKey) : 'null';
  }
  //${parameter?err_msg}, ${parameter:?err_msg}
  //  If parameter set, use it, else print err_msg and abort the script with an exit status of 1.
  case '?': {
    let prev;
    if ((prev=std.getenv(previousKey))) {
      return prev;
    } else {
      common.printError(currentKey);
      return currentValue;
    }
  }
  //${parameter=default}, ${parameter:=default}
  //  If parameter not set, set it to default.
  case '=': {
    if (!std.getenv(previousKey)) {
      std.setenv(previousKey, std.getenv(currentKey));
    }
    return std.getenv(previousKey);
  }
  default:
    return undefined;
  }
}


export function resolveShellTemplate(content: string): string {
  let position = 0;
  let output = '';
  
  while (position != -1 && position < content.length) {
    let index = content.indexOf('$', position);
    if (index == -1) {
      output+=content.substring(position);
      return output;
    } else {
      output+=content.substring(position, index);
      if (content[index+1] === '{') {
        let endIndex = content.indexOf('}', index+2);
        if (endIndex == -1) {
          output+=content.substring(position);
          return output;
        }
        
        //${#var}
        //  String length (number of characters in $var). For an array, ${#array} is the length of the first element in the array.
        if (content[index+2] === '#') {
          let value = std.getenv(content.substring(index+3, endIndex));
          if (value!==undefined) {
            output+=value.length;
            position=endIndex;
            continue;
          }
        }

        let accumIndex = index+2;
        let currentIndex = index+2;
        let envValue;
        let firstKey;
        let previousKey=null;
        let currentKey;
        let previousModifier;
        while ((currentIndex<endIndex) && (envValue===undefined)) {
          const char = content[currentIndex];
          if (char == '-' || char == '=' || char == '+' || char == '?') {
            currentKey=content.substring(accumIndex, currentIndex);
            if (currentKey.endsWith(':')) {
              //TODO this does not handle : cases different from non-: cases, unsure what to do with them
              currentKey = currentKey.substring(0,currentKey.length-1);
            }
            accumIndex=currentIndex+1;
            if (currentKey) {
              if (firstKey===undefined) {
                firstKey=currentKey;
                envValue=std.getenv(firstKey);
              }
            }
            if (previousModifier) {
              envValue = resolveShellVariable(previousKey, currentKey, envValue, previousModifier);
            }
            previousKey=currentKey;
            previousModifier = char;
          }
          currentIndex++;
        }
        
        currentKey=content.substring(accumIndex, currentIndex);
        if (currentKey.endsWith(':')) {
          //TODO this does not handle : cases different from non-: cases, unsure what to do with them
          currentKey = currentKey.substring(0,currentKey.length-1);
        }
        if (currentKey) {
          if (firstKey===undefined) {
            firstKey=currentKey;
            envValue=std.getenv(firstKey);
          }
        }
        if (previousModifier) {
          envValue = resolveShellVariable(previousKey, currentKey, envValue, previousModifier);
        }
        if (envValue!==undefined) {
          output+=envValue;
        }
        position=endIndex+1;
      } else {
        let keyIndex = index+1;
        let charCode = content.charCodeAt(keyIndex);
        while ((charCode <0x5b && charCode > 0x40) || (charCode < 0x7b && charCode > 0x60) || (charCode > 0x2f && charCode < 0x40) || (charCode == 0x5f)) {
          keyIndex++;
        }
        let val = std.getenv(content.substring(index+1, keyIndex));
        if (val!==undefined) {
          output+=val;
        }
        position=keyIndex;
      }
    }
  }
  return output;
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
          const resolvedContents = resolveShellTemplate(contents);

          const zweCliParameterHaInstance=std.getenv("ZWE_CLI_PARAMETER_HA_INSTANCE");
          const outPath=`${STATIC_DEF_DIR}/${componentName}.${sanitizedDefName}.${zweCliParameterHaInstance}.yml`;

          common.printDebug(`- writing ${outPath}`);

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
      common.printErrorAndExit("PC bit not set. This must be set such as by executing 'extattr +p $COMPONENT_HOME/lib/sys.so' as a user with sufficient privilege.");
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
