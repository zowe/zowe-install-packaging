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
import { PathAPI as pathoid } from './pathoid';
import * as common from './common';
import * as fs from './fs';
import * as zosfs from './zos-fs';
import * as zosdataset from './zos-dataset';
import * as stringlib from './string';
import * as shell from './shell';
import * as configmgr from './configmgr';
import * as varlib from './var';
import * as fakejq from './fakejq';
import * as configUtils from './config';

const CONFIG_MGR=configmgr.CONFIG_MGR;

let ZOWE_CONFIG: any = null;
let runtimeDirectory: string = '';
let extensionDirectory: string = '';
let workspaceDirectory: string = '';
let pluginPointerDirectory: string = '';

//key: name of config, value: boolean on if it is cached already
const configLoadedList:any = {};

//TODO this file is full of printErrorAndExit. unreasonable?
const MANIFEST_SCHEMA_ID = 'https://zowe.org/schemas/v2/server-component-manifest';
const PLUGIN_DEF_SCHEMA_ID = "https://zowe.org/schemas/v2/appfw-plugin-definition";
let COMMON_SCHEMA = '';
let MANIFEST_SCHEMAS = '';
let PLUGIN_DEF_SCHEMAS = '';

function loadConfig() {
  if (ZOWE_CONFIG == null) {
    ZOWE_CONFIG = configmgr.getZoweConfig();
  }
  runtimeDirectory=ZOWE_CONFIG.zowe.runtimeDirectory;
  extensionDirectory=ZOWE_CONFIG.zowe.extensionDirectory;
  workspaceDirectory=ZOWE_CONFIG.zowe.workspaceDirectory;
  pluginPointerDirectory = `${workspaceDirectory}/app-server/plugins`;
  COMMON_SCHEMA = `${runtimeDirectory}/schemas/server-common.json`;
  MANIFEST_SCHEMAS = `${runtimeDirectory}/schemas/manifest-schema.json:${COMMON_SCHEMA}`;
  PLUGIN_DEF_SCHEMAS = `${runtimeDirectory}/components/app-server/schemas/plugindefinition-schema.json`;
}

const INDIVIDUAL_APIML_COMPONENTS = ['gateway', 'discovery', 'api-catalog', 'caching-service', 'zaas'];

export function isComponentInAPIMLModulith(componentName: string): boolean {
  loadConfig();
  let apimlModulith = ZOWE_CONFIG.components.apiml?.enabled;
  return apimlModulith && INDIVIDUAL_APIML_COMPONENTS.includes(componentName);
}

export function getJobnameForComponent(componentName: string, componentManifest?: any): string {
  loadConfig();
  let apimlModulith = ZOWE_CONFIG.components.apiml?.enabled;
  let jobnamePrefix = ZOWE_CONFIG.zowe.job?.prefix || '';
  if (componentManifest && componentManifest.jobnameSuffix) {
    return jobnamePrefix + componentManifest.jobnameSuffix;
  } else if (componentManifest && componentManifest.jobname) {
    return componentManifest.jobname;
  } else {    
    switch (componentName) {
    case 'gateway':
      return jobnamePrefix+'AG';
    case 'discovery':
      if (apimlModulith) {
        return jobnamePrefix+'AG';
      } else {
        return jobnamePrefix+'AD';
      }
    case 'api-catalog':
      if (apimlModulith) {
        return jobnamePrefix+'AG';
      } else {
        return jobnamePrefix+'AC';
      }
    case 'caching-service':
      if (apimlModulith) {
        return jobnamePrefix+'AG';
      } else {
        return jobnamePrefix+'CS';
      }
    case 'zaas':
      if (apimlModulith) {
        return jobnamePrefix+'AG';
      } else {
        return jobnamePrefix+'AZ';
      }
    case 'zss':
      return jobnamePrefix+'SZ';
    case 'app-server':
      if ((std.getenv('ZLUX_NO_CLUSTER') == '1') || (ZOWE_CONFIG.zowe.environments?.ZLUX_NO_CLUSTER == 1)) {
        return jobnamePrefix+'DS';
      } else {
        //its probably the current jobname, but we have no field to gather that.
        return '';
      }
    default:
      //we dont know
      return '';
    }
  }
}

// This intentionally lies about individual apiml components for backward compatibility.
// If the apiml modulith is enabled, all are considered enabled.
export function getEnabledComponents() {
  loadConfig();
  let haInstance = configUtils.sanitizeHaInstanceId();
  let haConfig = configmgr.loadZoweConfig(haInstance);
  let components = Object.keys(haConfig.components);
  let enabled: string[] = [];
  let apimlModulithEnabled = haConfig.components.apiml.enabled == true;

  
  if (apimlModulithEnabled) {
    enabled = enabled.concat(INDIVIDUAL_APIML_COMPONENTS);
    
    //do not process individual apiml components further
    components = components.filter(name => !INDIVIDUAL_APIML_COMPONENTS.includes(name));
  }
  
  components.forEach((key) => {
    if (haConfig.components[key].enabled == true) {
      enabled.push(key);
    }
  });
  return enabled;
}

export function getManifestPath(componentDir: string): string|undefined {
  loadConfig();
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
  loadConfig();
  if (fs.directoryExists(`${runtimeDirectory}/components/${componentId}`)) {
    return `${runtimeDirectory}/components/${componentId}`;
  } else if (extensionDirectory && fs.directoryExists(`${extensionDirectory}/${componentId}`)) {
    return `${extensionDirectory}/${componentId}`;
  }
  return undefined;
}

export function registerPlugin(path:string, pluginDefinition:any){
  loadConfig();
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
  loadConfig();
  let blanks = "                                                                 ";
  let subs = e.subExceptions;
  common.printError(blanks.substring(0,depth*2)+e.message);
  if (subs){
    for (const sub of subs){
      showExceptions(sub,depth+1);
    }
  }
}

export function getPluginDefinition(pluginRootPath:string, continueOnFailure?: boolean) {
  loadConfig();
  const pluginDefinitionPath = `${pluginRootPath}/pluginDefinition.json`;
  const configId = `appfwPlugin:${pluginRootPath}`;

  const printer = continueOnFailure ? common.printError : common.printErrorAndExit;

  if (fs.fileExists(pluginDefinitionPath)) {
    let status;
    if ((status = CONFIG_MGR.addConfig(configId))) {
      printer(`Could not add config for ${pluginRootPath}, status=${status}`);
      return null;
    }
    
    if ((status = CONFIG_MGR.loadSchemas(configId, PLUGIN_DEF_SCHEMAS))) {
      printer(`Could not load schemas ${PLUGIN_DEF_SCHEMAS} for plugin ${pluginRootPath}, status=${status}`);
      return null;
    }


    if ((status = CONFIG_MGR.setConfigPath(configId, `FILE(${pluginDefinitionPath})`))) {
      printer(`Could not set config path for ${pluginDefinitionPath}, status=${status}`);
      return null;
    }
    if ((status = CONFIG_MGR.loadConfiguration(configId))) {
      printer(`Could not load config for ${pluginDefinitionPath}, status=${status}`);
      return null;
    }

    let validation = CONFIG_MGR.validate(configId);
    if (validation.ok){
      if (validation.exceptionTree){
        common.printError(`Validation of ${pluginDefinitionPath} against schema ${PLUGIN_DEF_SCHEMA_ID} found invalid JSON Schema data`);
        showExceptions(validation.exceptionTree, 0);
        if (!continueOnFailure) {
          std.exit(1);
        }
        return null;
      } else {
        return CONFIG_MGR.getConfigData(configId);
      }
    } else {
      printer(`Error occurred on validation of ${pluginDefinitionPath} against schema ${PLUGIN_DEF_SCHEMA_ID} `);
      return null;
    }
  } else {
    printer(`Plugin at ${pluginRootPath} has no pluginDefinition.json`);
    return null;
  }
}


export function getManifest(componentDirectory: string): any {
  loadConfig();
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

export function getSchemasForComponentConfig(manifest: any, componentDir: string): string|undefined {
  loadConfig();
  let baseSchemas = configmgr.getZoweBaseSchemas();
  if (manifest.schemas?.configs) {
    if (Array.isArray(manifest.schemas.configs)) {
      return manifest.schemas.configs.map(path=>componentDir+'/'+path).join(':')+":"+baseSchemas;
    } else {
      return componentDir+'/'+manifest.schemas.configs+":"+baseSchemas;
    }
  }
  return undefined;
}

export function validateConfigForComponent(componentId: string, manifest: any, componentDir: string, configPath: string): boolean {
  loadConfig();
  if (configPath.startsWith('/')) { //likely input is merged yaml
    configPath=`FILE(${configPath})`; 
  }
  const schemas = getSchemasForComponentConfig(manifest, componentDir);
  const validationMode = ZOWE_CONFIG.zowe.configmgr?.validation ? ZOWE_CONFIG.zowe.configmgr.validation : 'COMPONENT-COMPAT';
  if (!schemas && validationMode != 'COMPONENT-COMPAT') { //can be undefined if not stated in manifest.yaml
    common.printError(`Component ${componentId} is missing property manifest property schemas.configs, validation will fail`);
    return false;
  } else if (!schemas) {
    common.printError(`Error: DEPRECATED: Component ${componentId} does not have a schema file defined in manifest property schemas.configs! Skipping config validation for this component. This may fail in future versions of Zowe. Updating the component is recommended.`);
    return true;
  }

  const configRevisionName = `zowe.yaml-${componentId}`;

  if (configPath) {
    let status = 0;
    if ((status = CONFIG_MGR.addConfig(configRevisionName))) {
      common.printError(`Error: Could not add config for ${configPath}, status=${status}`);
      return false;
    }

    if ((status = CONFIG_MGR.loadSchemas(configRevisionName, schemas))) {
      common.printError(`Error: Could not load schemas ${schemas} for configs ${configPath}, status=${status}`);
      return false;
    }

    if ((status = CONFIG_MGR.setConfigPath(configRevisionName, configPath))) {
      common.printError(`Error: Could not set config path for ${configPath}, status=${status}`);
      return false;
    }

    if ((status = CONFIG_MGR.loadConfiguration(configRevisionName))) {
      common.printError(`Error: Could not load config for ${configPath}, status=${status}`);
      return false;
    }

    let validation = CONFIG_MGR.validate(configRevisionName);
    if (validation.ok){
      if (validation.exceptionTree){
        common.printError(`Error: Validation of ${configPath} against schema ${schemas} found invalid JSON Schema data`);
        showExceptions(validation.exceptionTree, 0);
        return false;
      } else {
        return true;
      }
    } else {
      common.printError(`Error: Error occurred on validation of ${configPath} against schema ${schemas}`);
      return false;
    }
  } else {
    common.printError(`Error: Server config path not given`);
    return false;
  }  

}

export function detectComponentManifestEncoding(componentDir: string): number|undefined {
  loadConfig();
  const manifestPath = getManifestPath(componentDir);
  if (!manifestPath) {
    return undefined;
  }
  const encoding = zosfs.detectFileEncoding(manifestPath, 'name');
  return encoding!==-1 ? encoding : undefined;
}

export function detectIfComponentTagged(componentDir: string): boolean {
  loadConfig();
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
  loadConfig();
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
  loadConfig();
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
  return getEnabledComponents();
}

export function findAllLaunchComponents(): string {
  return findAllLaunchComponents2().join(',');
}

export function findAllLaunchComponents2(): string[] {
  loadConfig();

  let enabledComponentsEnv=std.getenv('ZWE_ENABLED_COMPONENTS');
  let enabledComponents = enabledComponentsEnv ? enabledComponentsEnv.split(',') : null;
  if (!enabledComponents) {
    enabledComponents = findAllEnabledComponents2();
  }
  const usingApimlModulith = enabledComponents.includes('apiml');
  
  return enabledComponents.filter(function(component: string) {
    if (usingApimlModulith && INDIVIDUAL_APIML_COMPONENTS.includes(component)) {
      return false;
    }
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

function getBooleanEnv(variableName) {
  const value = std.getenv(`${variableName}`);
  if (value === "true") {
      return true
  }
  if (value === "false") {
      return false
  }
  return undefined
}


export function isClientAttls() {
  const clientGlobalAttls = getBooleanEnv('ZWE_zowe_network_client_tls_attls');
  const serverGlobalAttls = getBooleanEnv('ZWE_zowe_network_server_tls_attls');
  const clientLocalAttls = getBooleanEnv('ZWE_components_zaas_zowe_network_client_tls_attls');
  const serverLocalAttls = getBooleanEnv('ZWE_components_zaas_zowe_network_server_tls_attls');
  const clientAttls = clientGlobalAttls || clientLocalAttls;
  if ((clientGlobalAttls !== false) && (clientLocalAttls !== false) && (!clientAttls)) {
    // If client attls not explicitly false OR truthy, have client follow server attls variable. it simplifies common case in which users want both.
    return serverGlobalAttls || serverLocalAttls;
  } else {
    return clientAttls;
  }
}

// This function both creates static definition files from manifest templates,
// And cleans up existing ones that seem to be outdated
// It does not touch existing files that are neither - it continues to permit sideloaded static definition files
// TODO - this also means it permits outdated files from extensions that no longer exist.
//        uninstalling an extension does not do any such cleanup, so this bug continues to exist.
export function processComponentApimlStaticDefinitions(componentDir: string): boolean {
  loadConfig();

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

  let firstInstance;
  if (ZOWE_CONFIG.haInstances) {
    common.printDebug(`Checking for z/osmf HA duplicates`);
    let sortedKeys = Object.keys(ZOWE_CONFIG.haInstances).sort();
    if (sortedKeys.length > 0) {
      firstInstance = configUtils.sanitizeHaInstanceId(sortedKeys[0]);
    }
    //ensure first exists, swap values if necessary to do so. do not allow others to be created if once is set.
  }
  
  
  let allSucceed=true;
  const componentName = manifest.name;
  if (manifest.apimlServices && manifest.apimlServices.static) {
    let staticDefs = manifest.apimlServices.static;

    const existingFiles = fs.getFilesInDirectory(STATIC_DEF_DIR);
    const definedHaInstanceNames = ZOWE_CONFIG.haInstances ?
                                 Object.keys(ZOWE_CONFIG.haInstances).map(name=>configUtils.sanitizeHaInstanceId(name)) :
                                 [];

    const currentHaInstanceName = configUtils.sanitizeHaInstanceId();
    const haInstanceNames = definedHaInstanceNames.includes(currentHaInstanceName) ? definedHaInstanceNames : [currentHaInstanceName].concat(definedHaInstanceNames);

    
    for (let i = 0; i < staticDefs.length; i++) {
      const staticDef = staticDefs[i];
      const file=staticDef.file;
      const once = staticDef.once !== undefined ? staticDef.once : false;

      const haInstanceName = once ? firstInstance ? firstInstance : currentHaInstanceName : currentHaInstanceName;

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
          const zosmfScheme = std.getenv("ZOSMF_SCHEME");
          const attls = isClientAttls();
          const schemeEnv = std.getenv("ZWE_zOSMF_scheme");

          let scheme = "https";
          let securePortEnabled = true;
          let nonSecurePortEnabled = false;
          
          if (zosmfScheme) {
            scheme = zosmfScheme;
          } else if (schemeEnv) {
            scheme = schemeEnv;
          } else if (attls) {
            scheme = "http";
          }

          if (scheme === "http") {
            securePortEnabled = false;
            nonSecurePortEnabled = true;
          }
          
          std.setenv('ZOSMF_SCHEME', scheme);
          std.setenv('ZOSMF_NON_SECURE_PORT_ENABLED', `${nonSecurePortEnabled}`);
          std.setenv('ZOSMF_SECURE_PORT_ENABLED', `${securePortEnabled}`);

          const zosmfAuthenticationScheme = ([ 'zosmf', 'httpBasicPassTicket' ].includes(std.getenv('ZOSMF_AUTHENTICATION_SCHEME'))) ? std.getenv('ZOSMF_AUTHENTICATION_SCHEME') : std.getenv('ZWE_zOSMF_authentication_scheme');
          let authProvider = (['saf', 'zosmf', 'dummy'].includes(std.getenv('ZWE_components_apiml_apiml_security_auth_provider'))) ? std.getenv('ZWE_components_apiml_apiml_security_auth_provider') : std.getenv('ZWE_components_gateway_apiml_security_auth_provider');
          // default auth provider to z/osmf for 3.x, consistent with apiml
          if (!authProvider) {
            authProvider = 'zosmf';
          }
          let authScheme = zosmfAuthenticationScheme || 'zosmf';
          if (!zosmfAuthenticationScheme && (authProvider === 'saf')) {
            authScheme = 'httpBasicPassTicket';
          }
          std.setenv('ZOSMF_AUTHENTICATION_SCHEME', authScheme);

          const resolvedContents = varlib.resolveShellTemplate(contents);

          
          //discovery static code requires specifically .yml. Not .yaml
          const outFileName = `${componentName}.${sanitizedDefName}.${haInstanceName}.yml`;
          const outPath=`${STATIC_DEF_DIR}/${outFileName}`;

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

          //cleanup outdated static definision files of same type
          common.printDebug(`Checking for old static defs for cleanup`);
          if (existingFiles) {
            let prefix = `${componentName}.${sanitizedDefName}.`;
            let apimlPrefix = `apiml.${sanitizedDefName}.`;
            let discoveryPrefix = `discovery.${sanitizedDefName}.`;
            let suffix = '.yml';
            for (let i = 0; i < existingFiles.length; i++) {
              let existingFile = existingFiles[i];
              if (existingFile.endsWith(suffix)) {
                if (existingFile.startsWith(prefix)) {
                  let haInstanceFound = existingFile.substring(prefix.length, existingFile.length - suffix.length);
                  if (!haInstanceNames.includes(haInstanceFound) && existingFile != outFileName) {
                    common.printDebug(`Removing outdated static def ${existingFile}`);
                    os.remove(`${STATIC_DEF_DIR}/${existingFile}`);
                  } else if (once && (existingFile != outFileName)) {
                    common.printDebug(`Removing duplicate of once static def ${existingFile}`);
                    os.remove(`${STATIC_DEF_DIR}/${existingFile}`);
                  } else {
                    common.printDebug(`Ignored static def ${existingFile}`);
                  }
                } else if (componentName == 'discovery' && existingFile.startsWith(apimlPrefix)) {
                  common.printDebug(`Removing apiml modulith static def ${existingFile}`);
                  os.remove(`${STATIC_DEF_DIR}/${existingFile}`);
                } else if (componentName == 'apiml' && existingFile.startsWith(discoveryPrefix)) {
                  common.printDebug(`Removing discovery non-modulith static def ${existingFile}`);
                  os.remove(`${STATIC_DEF_DIR}/${existingFile}`);
                } else {
                  common.printDebug(`Ignored static def ${existingFile}`);
                }
              }
            }
          } else {
            common.printDebug(`No prior static defs for ${componentName} found`);
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
export function testOrSetPcBit(path: string, exitOnError?: boolean, dryRun?: boolean): boolean {
  loadConfig();

  if (!hasPCBit(path)) {
    common.printError(`ZSS plugin "${path}" not program controlled. Adding PC bit.`);
    if (!dryRun) {
      zos.changeExtAttr(path, zos.EXTATTR_PROGCTL, true);
      const success = hasPCBit(path);
      if (!success) {
        common.printErrorAndConditionallyExit(`PC bit not set. This must be set such as by executing 'extattr +p ${path}' as a user with sufficient privilege.`, undefined, 4, exitOnError);
      }
      return success;
    } else {
      common.printMessage(`Dry run: Operation skipped. Operation can be performed manually via command 'extattr +p ${path}'`);
    }
    return true;
  } else {
    return true;
  }
}

export function hasPCBit(path: string): boolean {
  loadConfig();

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


export function checkZssPcBit(appfwPluginPath: string, exitOnError?: boolean, dryRun?: boolean): {serviceCount: number, errors: number} {
  loadConfig();

  let serviceCount = 0;
  let errors = 0;

  const pluginDefinition = getPluginDefinition(appfwPluginPath);
  if (pluginDefinition) {
    if (pluginDefinition.dataServices) {
      common.printDebug(`Checking ZSS services in plugin path=${appfwPluginPath}`);
      pluginDefinition.dataServices.forEach(function(service: any){
        if (service.type == 'service') {
          serviceCount++;
          if (os.platform == 'zos') {
            if (service.libraryName31) {
              if (!testOrSetPcBit(`${appfwPluginPath}/lib/${service.libraryName31}`, exitOnError, dryRun)) {
                errors++;
              }
            }
            if (service.libraryName64) {
              if (!testOrSetPcBit(`${appfwPluginPath}/lib/${service.libraryName64}`, exitOnError, dryRun)) {
                errors++;
              }
            }
            if (service.libraryName) {
              if (!testOrSetPcBit(`${appfwPluginPath}/lib/${service.libraryName}`, exitOnError, dryRun)) {
                errors++;
              }
            }
          }
        }
      });
    }
    return {serviceCount: serviceCount, errors: errors};
  } else {
    common.printErrorAndConditionallyExit(`Skipping ZSS PC bit check of plugin at ${appfwPluginPath} due to pluginDefinition missing or invalid`, undefined, 4, exitOnError);
    return {serviceCount: 0, errors: 1};
  }
}

export function processZssPluginInstall(componentDir: string, exitOnError?: boolean, dryRun?: boolean): void {
  loadConfig();
  common.printDebug(`Checking for zss plugins and verifying them`);
  if (!fs.directoryExists(componentDir)) {
    common.printErrorAndConditionallyExit(`Component directory ${componentDir} not found or insufficient permission.`, undefined, 4, exitOnError);
  }
  let appfwPluginCount, serviceCount, errors = 0;
  const manifest = getManifest(componentDir);
  if (manifest && manifest.appfwPlugins) {
    manifest.appfwPlugins.forEach(function(appfwPlugin: any) {
      appfwPluginCount++;
      const path = appfwPlugin.path;
      let result = checkZssPcBit(`${componentDir}/${path}`, exitOnError, dryRun);
      errors = errors + result.errors;
      serviceCount = serviceCount + result.serviceCount;
    });
  } else if (!manifest) {
    common.printErrorAndConditionallyExit(`Invalid component. Component manifest not found in ${componentDir}.`, undefined, 4, exitOnError);
  }
  if (serviceCount > 0 && (os.platform != 'zos')) {
    common.printMessage(`Component includes ZSS plugins which cannot be handled because install is not on z/OS.`);
    common.printMessage(`Run component installation on a Zowe z/OS installation as well to complete the ZSS plugin installs`);
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
export function processZisPluginInstall(componentDir: string, zisPluginDatasets?: string[], exitOnError?: boolean, dryRun?: boolean): number {
  loadConfig();
  let highestRc = 0;

  if (zisPluginDatasets) {
    if(!addPluginToZisSteplib(zisPluginDatasets, dryRun)) {
      common.printError(`Error in updating the zis stcs STEPLIB entries for zis plugin install`);
      return 1;
    }
  } else {
    let errors = addPluginsToZisAuthLoadlib(componentDir, dryRun);
    errors.forEach((error)=> {
      common.printError(`Failed to add loadlib for ZIS plugin ${error.plugin}, rc=${error.rc}`);
      if (error.rc > highestRc) {
        highestRc = error.rc;
      }
    })
  }

  if (highestRc) {
    return highestRc;
  } else {
    let errors = zisParmlibRegister(componentDir, exitOnError, dryRun);
    errors.forEach((error)=> {
      common.printError(`Failed to register ZIS plugin ${error.plugin} into ZIS parmlib, rc=${error.rc}`);
      if (error.rc > highestRc) {
        highestRc = error.rc;
      }
    });
    
    return highestRc;
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

export function zisParmlibRegister(componentDir: string, exitOnError?: boolean, dryRun?: boolean): {rc: number, plugin: string}[] {
  let errors: {rc: number, plugin: string}[] = [];

  const manifest = getManifest(componentDir);
  if (manifest?.zisPlugins && (manifest.zisPlugins.length > 0)) {
    if (os.platform != 'zos') {
      common.printError(`ZIS plugin installation must be done on z/OS.`);
      return [{rc: 1, plugin: ''}]
    }

    const ZOWE_CONFIG = configUtils.getZoweConfig();
    let zoweParmlib = ZOWE_CONFIG.zowe.setup?.dataset?.parmlib;
    if (!zoweParmlib && ZOWE_CONFIG.zowe.setup?.dataset?.prefix) {
      zoweParmlib = ZOWE_CONFIG.zowe.setup.dataset.prefix + '.CUST.PARMLIB';
    }
    if (!zoweParmlib) {
      common.printError(`Property zowe.setup.dataset.parmlib not defined in YAML`);
      return [{rc: 1, plugin: ''}];
    }
    let zisParmlibMember = ZOWE_CONFIG.zowe.setup?.dataset?.parmlibMembers?.zis;
    if (!zisParmlibMember) {
      zisParmlibMember = 'ZWESIP00';
      common.printMessage(`Property zowe.setup.dataset.parmlibMembers.zis not defined in YAML\nDefaulting to ${zisParmlibMember}`);
    }

    let rc = zosdataset.isDatasetExistsRC(`${zoweParmlib}(${zisParmlibMember})`);
    if (rc) {
      common.printError(`Parmlib member defined in zowe.setup.dataset.parmlib and zowe.setup.dataset.parmlibMembers.zis not found\nDataset: ${zoweParmlib}, member: ${zisParmlibMember} rc: ${rc}`);
      return [{rc: rc, plugin: ''}]
    }



    const parmlibMemberAsUnixFile=fs.createTmpFile(zisParmlibMember);
    zosfs.copyMvsToUss(`${zoweParmlib}(${zisParmlibMember})`, parmlibMemberAsUnixFile);
    let parmlibContents = xplatform.loadFileUTF8(parmlibMemberAsUnixFile, xplatform.AUTO_DETECT);
    let parmlibChanged = false;
    common.printMessage(`PARMLIB is currently: \n${parmlibContents}`);

    for (let i = 0; i < manifest.zisPlugins.length; i++) {
      const zisPlugin: {path: string, id: string} = manifest.zisPlugins[i];
      const pluginRootPath = pathoid.join(componentDir, zisPlugin.path);
      const samplibPath=`${pluginRootPath}/samplib`;

      if (!fs.directoryExists(samplibPath)) {
        common.printError(`Directory ${samplibPath} does not exist`);
        errors.push({rc: 1, plugin: zisPlugin.id});
        continue;
      }

      common.printMessage(`Registering ZIS plugin ${zisPlugin.id} into PARMLIB ${zoweParmlib}(${zisParmlibMember})`);

      let result = editZisParmlibContents(parmlibContents, ZOWE_CONFIG.zowe.setup?.zis?.parmlib?.keys, samplibPath);

      if (result.rc) {
        common.printMessage(`Failed to update ZIS PARMLIB for plugin: ${zisPlugin.id}, rc=${rc}`);
        errors.push({rc: result.rc, plugin: zisPlugin.id});
        continue;
      } else if (result.changed) {
        parmlibChanged = true;
        parmlibContents = result.content;
        common.printDebug(`PARMLIB with edits: \n${parmlibContents}`);

      } else {
        common.printMessage(`No change to PARMLIB needed.`);
      }
    }

    if (!dryRun && (parmlibChanged === true)) {
      xplatform.storeFileUTF8(parmlibMemberAsUnixFile, xplatform.AUTO_DETECT, parmlibContents);
      rc = zosdataset.copyToDataset(parmlibMemberAsUnixFile, `${zoweParmlib}(${zisParmlibMember})`, "", true);
      if (rc != 0) {
        common.printError(`Error ZWEL0200E: Failed to copy USS file ${parmlibMemberAsUnixFile} to MVS data set ${zoweParmlib}.`);
      }
      errors.push({rc: rc, plugin: ''});
    } else {
      common.printMessage(`Dry run: no update performed. Edited PARMLIB available as unix file ${parmlibMemberAsUnixFile}`);
      common.printMessage(`PARMLIB content preview: \n${parmlibContents}`);
    }

    
    return errors;
  } else {
    common.printDebug(`Component ${manifest.name} does not have ZIS plugins, action skipped`);
    return [];
  }
}

function editZisParmlibContents(parmlibContents: string, parmlibKeys: any, samplibPath: string): {rc:number, changed:boolean, content: string}{
  let rc = 0;
  let parmlibLines = parmlibContents.split('\n');
  
  let changed = false; 
  const files = fs.getFilesInDirectory(samplibPath);
  
  for (let i = 0; i < files.length; i++) {
    const params = files[i];
    if (!fs.fileExists(`${samplibPath}/${params}`)) {
      common.printError(`Error ZWEL0201E: File ${samplibPath}/${params} does not exist.`);
      rc = 201;
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
            rc = 1;
          } else if (result.changed) {
            parmlibContents = result.contents;
            parmlibLines = parmlibContents.split('\n');
            changed = true;
          }
        }
      }
    });
  }

  return {rc: rc, changed: changed, content: parmlibContents};
}

export function addPluginsToZisAuthLoadlib(componentDir: string, dryRun?: boolean): {rc: number, plugin: string}[] {
  let errors: {rc: number, plugin: string}[] = [];
  
  const manifest = getManifest(componentDir);
  if (manifest?.zisPlugins) {
    if (os.platform != 'zos') {
      common.printError(`ZIS plugin installation must be done on z/OS.`);
      return [{rc: 1, plugin: ''}]
    }

    const ZOWE_CONFIG = configUtils.getZoweConfig();
    let zisPluginLib = ZOWE_CONFIG.zowe.setup?.dataset?.authLoadlib;
    if (!zisPluginLib && ZOWE_CONFIG.zowe.setup?.dataset?.prefix) {
      zisPluginLib = ZOWE_CONFIG.zowe.setup.dataset.prefix + '.SZWEAPL';
      common.printMessage(`Property zowe.setup.dataset.authLoadlib not defined in YAML\nDefaulting to ${zisPluginLib}`);
    }
    if (!zisPluginLib) {
      common.printError(`Property zowe.setup.dataset.authLoadlib not defined in YAML`);
      return [{rc: 1, plugin: ''}]
    } else {
      let rc = zosdataset.isDatasetExistsRC(zisPluginLib);
      if (rc) {
        common.printError(`Dataset defined in zowe.setup.dataset.authLoadlib not found\nDataset: ${zisPluginLib}, rc: ${rc}`);
        return [{rc: rc, plugin: ''}]
      }
    }


    common.printMessage(`Copying ZIS plugins from component ${manifest.name} into LOADLIB ${zisPluginLib}`);
    
    for (let i = 0; i < manifest.zisPlugins.length; i++) {
      const zisPlugin: {path: string, id: string} = manifest.zisPlugins[i];
      const pluginRootPath = pathoid.join(componentDir, zisPlugin.path);      
      const loadLibPath=`${pluginRootPath}/loadlib`;
      
      const plugins = fs.getFilesInDirectory(loadLibPath) || [];
      if (!plugins) {
        common.printError(`No ZIS plugin content found within ${loadLibPath} for ${zisPlugin.id}`);
        errors.push({rc: 1, plugin: zisPlugin.id});
        continue;
      }
      common.printMessage(`- Copying ${zisPlugin.id} at ${loadLibPath}`);

      for (let i = 0; i < plugins.length; i++) {
        const plugin = plugins[i];
        let sourcePath = `${loadLibPath}/${plugin}`;
        common.printMessage(`--- Member ${sourcePath}`);
        if (!dryRun) {
          let rc = zosdataset.copyToDataset(sourcePath, zisPluginLib, "", true);
          if (rc) {
            errors.push({rc: rc, plugin: plugin});
          }
        }
      }
    }
    return errors;
  } else {
    common.printDebug(`Component ${manifest.name} does not have ZIS plugins, action skipped`);
    return [];
  }
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
    if (!parmlibKeys) {
      throw new Error(`YAML section zowe.setup.zis.parmlib.keys missing value for ${samplibKey}`);
    }
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
  loadConfig();
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
 Parse and process manifest Zaas Shared Libs (zaasSharedLibs) definitions
 The supported manifest entry is ".zaasSharedLibs". All shared libs
 defined will be passed to install-app.sh for proper installation.
*/
export function processComponentZaasSharedLibs(componentDir: string): boolean {
  loadConfig();
  const zaasSharedLibs = std.getenv('ZWE_ZAAS_SHARED_LIBS');
  fs.mkdirp(zaasSharedLibs, 0o770);

  const manifest = getManifest(componentDir);
  let pluginName;
  let zaasSharedLibsWorkspacePath:string|undefined;
  
  if (manifest && manifest.zaasSharedLibs) {
    for (let i = 0; i < manifest.zaasSharedLibs.length; i++) {
      const zaasSharedLibsDef = manifest.zaasSharedLibs[i];
      const fileOrDir=`${componentDir}/${zaasSharedLibsDef}`;
      if (!pluginName) {
        pluginName = manifest.name;
        if (!pluginName) {
          common.printError(`Cannot read name from the plugin ${componentDir}`);
          return false;
        }
        zaasSharedLibsWorkspacePath = `${zaasSharedLibs}/${pluginName}`;
        fs.mkdirp(zaasSharedLibsWorkspacePath, 0o770);
      }

      if (!zaasSharedLibsWorkspacePath){
        common.printError("Unexpected error: did not find zaasSharedLibsWorkspacePath");
        return false;
      }

      const manifestPath = getManifestPath(componentDir);
      if (manifestPath){
        fs.cp(manifestPath, zaasSharedLibsWorkspacePath);
      }

      if (fs.fileExists(fileOrDir)) {
        fs.cp(fileOrDir, zaasSharedLibsWorkspacePath);
      } else if (fs.directoryExists(fileOrDir)) {
        fs.cp(`${fileOrDir}/\*`, zaasSharedLibsWorkspacePath);
      } else {
        common.printError(`Zaas shared libs directory ${fileOrDir} is not accessible`);
        return false;
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
  loadConfig();
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
  loadConfig();
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


export function addPluginToZisSteplib(zisPluginDatasets: string[], dryRun?: boolean) : boolean {
  if (os.platform != 'zos') {
    common.printError(`ZIS plugin installation must be done on z/OS.`);
    return false;
  }
  const ZOWE_CONFIG = configUtils.getZoweConfig();
  const proclib = ZOWE_CONFIG.zowe.setup?.dataset?.proclib;
  const zisMember = ZOWE_CONFIG.zowe.setup?.security?.stcs?.zis;
  const auxMember = ZOWE_CONFIG.zowe.setup?.security?.stcs?.aux;

  if (!proclib) {
    common.printError(`zowe.setup.dataset.proclib is not defined in Zowe YAML, cannot add ZIS plugin to STC JCLs`);
    return false;
  } else if (!zisMember) {
    common.printError(`zowe.setup.security.stcs.zis is not defined in Zowe YAML cannot add ZIS plugin to STC JCL`);
    return false;
  } else if (!zosdataset.isDatasetExists(`${proclib}(${zisMember})`)) {
    common.printError(`ZIS proclib member ${proclib}(${zisMember}) not found.`);
    common.printError(`ZIS plugin cannot be added.`);
    common.printError(`Review Zowe YAML entries:`);
    common.printError(`- zowe.setup.dataset.proclib`);
    common.printError(`- zowe.setup.security.stcs.zis`);
    return false;
  } else if (!auxMember) {
    common.printError(`zowe.setup.security.stcs.aux is not defined in Zowe YAML, cannot add ZIS plugin to STC JCL`);
    return false;
  } else if (!zosdataset.isDatasetExists(`${proclib}(${auxMember})`)) {
    common.printError(`ZIS AUX proclib member ${proclib}(${auxMember}) not found.`);
    common.printError(`ZIS plugin cannot be added.`);
    common.printError(`Review Zowe YAML entries:`);
    common.printError(`- zowe.setup.dataset.proclib`);
    common.printError(`- zowe.setup.security.stcs.aux`);
    return false;

  }

  let datasetMissing = false;
  zisPluginDatasets.forEach((datasetName)=> {
    let rc = zosdataset.isDatasetExistsRC(datasetName);
    if (rc) {
      common.printError(`Plugin dataset does not exist\nDataset: ${datasetName}, rc: ${rc}`);
    }
  });
  if (datasetMissing) {
    return false;
  }


  // process zis plugin dataset arguements with multiple checks, eg Regex, duplicates etc
  const stepLibEntries = processZisPluginDatasetArgs(zisPluginDatasets);

  common.printMessage(`Adding STEPLIB entries for ZIS plugin datasets:`);
  zisPluginDatasets.forEach((dataset:string)=> {
    common.printMessage(`- ${dataset}`);
  });
  
  // Update the ZIS STC
  common.printMessage(`Updating ZIS STC ${proclib}(${zisMember})`);
  if (!updateStcSteplibEntries(proclib, zisMember, stepLibEntries, dryRun)) {
    common.printError(`${proclib}(${zisMember}) could not be updated`);
    return false;
  }

  // Update the AUX STC
  common.printMessage(`Updating AUX STC ${proclib}(${auxMember})`);
  if (!updateStcSteplibEntries(proclib, auxMember, stepLibEntries, dryRun)) {
    common.printError(`${proclib}(${zisMember}) could not be updated`);
    return false;
  }

  return true;
}

function updateStcSteplibEntries(proclib: string, member: string, stepLibEntries: string[], dryRun?: boolean): boolean {
  let success = true;

  // 1. create temporary Unix file
  const proclibMemberAsUnixFile = fs.createTmpFile(`${proclib}`);
  zosfs.copyMvsToUss(`${proclib}(${member})`, proclibMemberAsUnixFile);
    
  // 2. Get the updated content
  const updatedContent = updateStepLib(proclibMemberAsUnixFile, stepLibEntries);

  // 3. store the updated content in the same temporary Unix file
  let rc = xplatform.storeFileUTF8(proclibMemberAsUnixFile, xplatform.AUTO_DETECT, updatedContent);
  if (!rc) {
    if (!dryRun) { 
      // 4. Copy the file to destination
      rc = zosdataset.copyToDataset(proclibMemberAsUnixFile, `${proclib}(${member})`, "", true);
      if (rc) {
        common.printError(`Copy of temporary to dataset to ${proclib}(${member}) did not happen`);
        success = false;
      } else {
        common.printMessage(`${proclib}(${member}) updated successfully with new stepLib entries`);
      }
    } else {
      common.printMessage(`Dry run: no update performed. Edited JCL available as unix file ${proclibMemberAsUnixFile}`);
    }
  } else {
    common.printError(`Error: Could not store updated contents in tmp unix file ${proclibMemberAsUnixFile}.`);
    success = false;
  }
  return success;
}

function processZisPluginDatasetArgs(inputArgs: string[]): string[] {
  return Array.from(
    new Set(
      inputArgs
        .map(word => word.trim())
        .map(word => word.toUpperCase())
        .filter(word => word !== "")
        .filter(word => regexCheckDataset(word) && word.length <= 44)
        .filter(word => zosdataset.isDatasetExists(word))
    )
  );
}

const regexCheckDataset = (word: string): boolean => {
  const datasetRegex = /^([A-Z\$\#\@]){1}([A-Z0-9\$\#\@\-]){0,7}(\.([A-Z\$\#\@]){1}([A-Z0-9\$\#\@\-]){0,7}){0,11}$/
  return datasetRegex.test(word);
}

// Goes through the steplib section and adds entries, skipping blank lines and commented lines. However if an entry is commented and is
// part of new list of entries, then we uncomment that entry/line.
function updateStepLib(procLibfile: string, newStepLibEntries:  string[], dryRun?: boolean) : any {
  let procJcl = xplatform.loadFileUTF8(procLibfile, xplatform.AUTO_DETECT);
  common.printMessage(`JCL is currently: \n${procJcl}`);

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

  let result = lines.join("\n");
  common.printMessage(`JCL with edits: \n${result}`);
  return result;
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
