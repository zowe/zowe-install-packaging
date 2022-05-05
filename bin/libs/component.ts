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

import { ConfigManager } from 'Configuration';
import * as fs from './fs';
import * as stringlib from './string';
import * as common from './common';

const runtimeDirectory=std.getenv('ZWE_zowe_runtimeDirectory');
const extensionDirectory=std.getenv('ZWE_zowe_extensionDirectory');
const workspaceDirectory=std.getenv('ZWE_zowe_workspaceDirectory');

const configMgr = new ConfigManager();
configMgr.setTraceLevel(0);


/*
  Init the global schemas like manifest and zowe.yaml.
*/
const COMMON_SCHEMA = `${runtimeDirectory}/schemas/server-common.json`;
const ZOWE_SCHEMA_ID = 'https://zowe.org/schemas/v2/server-base';
const MANIFEST_SCHEMA_ID = 'https://zowe.org/schemas/v2/server-component-manifest';
const MANIFEST_SCHEMAS = `${runtimeDirectory}/schemas/manifest-schema.json:${COMMON_SCHEMA}`;

function initGlobalSchemas(runtimeDirectory) {
  configMgr.addConfig(ZOWE_SCHEMA_ID) || configMgrFailMessage(ZOWE_SCHEMA_ID);
  configMgr.loadSchemas(ZOWE_SCHEMA_ID, `${runtimeDirectory}/schemas/zowe-yaml-schema.json:${COMMON_SCHEMA}`) || configMgrFailMessage(ZOWE_SCHEMA_ID);
}




function getComponentManifest(componentDir: string): string|undefined {
  if (fs.fileExists(`${componentDir}/manifest.yaml`)) {
    return `${componentDir}/manifest.yaml`;
  } else if (fs.fileExists(`${componentDir}/manifest.yml`)) {
    return `${componentDir}/manifest.yml`;
  } else if (fs.fileExists(`${componentDir}/manifest.yaml`)) {
    return `${componentDir}/manifest.json`;
  }
}

function findComponentDirectory(componentId: string): string|undefined {
  if (fs.directoryExists(`${runtimeDirectory}/components/${componentId}`)) {
    return `${runtimeDirectory}/components/${componentId}`;
  } else if (extensionDirectory && fs.directoryExists(`${extensionDirectory}/${componentId}`)) {
    return `${extensionDirectory}/${componentId}`;
  }
}

const pluginPointerDirectory = `${workspaceDirectory}/app-server/plugins`;
function registerPlugin(path, pluginDefinition) {
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


const PLUGIN_DEF_SCHEMA_ID = "https://zowe.org/schemas/v2/appfw-plugin-definition";
const PLUGIN_DEF_SCHEMAS = `${runtimeDirectory}/components/app-server/schemas/plugindefinition-schema.json`;

function getPluginDefinition(pluginRootPath) {
  const pluginDefinitionPath = `${pluginRootPath}/pluginDefinition.json`;

  if (fs.fileExists(pluginDefinitionPath)) {
    let status;
    if ((status = configMgr.addConfig(pluginRootPath))) {
      console.log(`Could not add config for ${pluginRootPath}, status=${status}`);
      return null;
    }
    
    if ((status = configMgr.loadSchemas(pluginRootPath, PLUGIN_DEF_SCHEMAS))) {
      console.log(`Could not load schemas ${PLUGIN_DEF_SCHEMAS} for plugin ${pluginRootPath}, status=${status}`);
      return null;
    }


    if ((status = configMgr.setConfigPath(pluginRootPath, `FILE(${pluginDefinitionPath})`))) {
      console.log(`Could not set config path for ${pluginDefinitionPath}, status=${status}`);
      return null;
    }
    if ((status = configMgr.loadConfiguration(pluginRootPath))) {
      console.log(`Could not load config for ${pluginDefinitionPath}, status=${status}`);
      return null;
    }

    let validation = configMgr.validate(pluginRootPath);
    if (validation.ok){
      if (validation.exceptions){
        console.log(`Validation of ${pluginDefinitionPath} against schema ${PLUGIN_DEF_SCHEMA_ID} found invalid JSON Schema data`);
        for (let i=0; i<validation.exceptions.length; i++){
          console.log("    "+validation.exceptions[i]);
        }
        return null;
      } else {
        return configMgr.getConfigData(pluginRootPath);
      }
    } else {
      console.log(`Error occurred on validation of ${pluginDefinitionPath} against schema ${PLUGIN_DEF_SCHEMA_ID} `);
      return null;
    }
  } else {
    console.log(`Plugin at ${pluginRootPath} has no pluginDefinition.json`);
    return null;
  }
}


function getManifest(componentDirectory: string): any {
  let manifestPath = getComponentManifest(componentDirectory);

  if (manifestPath) {
    let status;

    let manifestId = componentDirectory;

    if ((status = configMgr.addConfig(manifestId))) {
      console.log(`Could not add config for ${manifestPath}, status=${status}`);
      return null;
    }

    if ((status = configMgr.loadSchemas(manifestId, MANIFEST_SCHEMAS))) {
      console.log(`Could not load schemas ${MANIFEST_SCHEMAS} for manifest ${manifestPath}, status=${status}`);
      return null;
    }

    if ((status = configMgr.setConfigPath(manifestId, `FILE(${manifestPath})`))) {
      console.log(`Could not set config path for ${manifestPath}, status=${status}`);
      return null;
    }

    if ((status = configMgr.loadConfiguration(manifestId))) {
      console.log(`Could not load config for ${manifestPath}, status=${status}`);
      return null;
    }

    let validation = configMgr.validate(manifestId);
    if (validation.ok){
      if (validation.exceptions){
        console.log(`Validation of ${manifestPath} against schema ${MANIFEST_SCHEMA_ID} found invalid JSON Schema data`);
        for (let i=0; i<validation.exceptions.length; i++){
          console.log("    "+validation.exceptions[i]);
        }
        return null;
      } else {
        return configMgr.getConfigData(manifestId);
      }
    } else {
      console.log(`Error occurred on validation of ${manifestPath} against schema ${MANIFEST_SCHEMA_ID} `);
      return null;
    }
  } else {
    console.log(`Component at ${componentDirectory} has no manifest`);
    return null;
  }
}

function readComponentManifest(componentDir: string, manifestKey: string): any {
  let manifest = getManifest(componentDir);
  if (manifest) {
    //TODO
  }
}

function detectcomponentManifestEncoding(componentDir: string) {
  //TODO
}

function detectIfComponentTagged(componentDir: string): boolean {
  return false;
  //TODO
}

function findAllInstalledComponents(): string {
  let components='';
  let subDirectories = fs.getSubdirectories(`${runtimeDirectory}/components`);
  if (subDirectories) {
    subDirectories.forEach((component:string)=> {
      if (getComponentManifest(`${runtimeDirectory}/components/${component}`)) {
        components=`${components},${component}`;
      }
    });
  }

  if (extensionDirectory) {
    subDirectories = fs.getSubdirectories(extensionDirectory);
    if (subDirectories) {
      subDirectories.forEach((component: string)=> {
        if (getComponentManifest(`${extensionDirectory}/${component}`)) {
          components=`${components},${component}`;  
        }
      });
    }
  }
  return components.length > 1 ? components.substring(1) : components;
}

function findAllInstalledComponents2(): string[] {
  let components=[];
  let subDirectories = fs.getSubdirectories(`${runtimeDirectory}/components`);
  if (subDirectories) {
    subDirectories.forEach((component:string)=> {
      if (getComponentManifest(`${runtimeDirectory}/components/${component}`)) {
        components.push(component);
      }
    });
  }

  if (extensionDirectory) {
    subDirectories = fs.getSubdirectories(extensionDirectory);
    if (subDirectories) {
      subDirectories.forEach((component: string)=> {
        if (getComponentManifest(`${extensionDirectory}/${component}`)) {
          components.push(component);
        }
      });
    }
  }
  return components;
}

function findAllEnabledComponents(): string {
  return findAllEnabledComponents2().join(',');
}

function findAllEnabledComponents2(): string[] {
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

function findAllLaunchComponents(): string {
  return findAllLaunchComponents2().join(',');
}

function findAllLaunchComponents2(): string[] {
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

/* if i run through ${} and $ i can call std.getenv to do substitution without invoking shell
rules:

${parameter}

    Same as $parameter, i.e., value of the variable parameter. In certain contexts, only the less ambiguous ${parameter} form works.

${parameter-default}, ${parameter:-default}

    If parameter not set, use default.

	

${parameter-default} and ${parameter:-default} are almost equivalent. The extra : makes a difference only when parameter has been declared, but is null. 

${parameter=default}, ${parameter:=default}

    If parameter not set, set it to default.

${parameter+alt_value}, ${parameter:+alt_value}

    If parameter set, use alt_value, else use null string.

${parameter?err_msg}, ${parameter:?err_msg}

    If parameter set, use it, else print err_msg and abort the script with an exit status of 1.

${#var}

    String length (number of characters in $var). For an array, ${#array} is the length of the first element in the array.

${var#Pattern}, ${var##Pattern}

    ${var#Pattern} Remove from $var the shortest part of $Pattern that matches the front end of $var.

    ${var##Pattern} Remove from $var the longest part of $Pattern that matches the front end of $var. 



   consider ${parameter:-default}

function substituteEnv(contents: string) {
  let index: number = 0;
  
}
*/


const STATIC_DEF_DIR=std.getenv('ZWE_STATIC_DEFINITIONS_DIR');
function processComponentApimlStaticDefinitions(componentDir: string): boolean {
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
        console.log(`Process ${componentName} service static definition file ${file}`);
        const sanitizedDefName=stringlib.sanitizeAlphanum(file);

        //TODO handle env var resolution in template file
        const outHandler = function(data: any) {
          console.log('Out handler got',data);
        };
        const defContents = os.exec(['sh', `( echo "cat <<EOF" ; cat "${path}" ; echo EOF ) | sh`],
                                    {block: true, usePath: true, stdout: outHandler});

        const zweCliParameterHaInstance=std.getenv("ZWE_CLI_PARAMETER_HA_INSTANCE");
        const outPath=`${STATIC_DEF_DIR}/${componentName}.${sanitizedDefName}.${zweCliParameterHaInstance}.yaml`;

        common.printDebug(`- writing ${outPath}`);

        const buff = stringlib.stringToBuffer(defContents);
        fs.createFileFromBuffer(outPath, 0o770, buff);
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
function testOrSetPcBit(path: string): boolean {
  //zos.changeTag
  if (!hasPCBit(path)) {
    console.log("Plugin ZSS API not program controlled. Attempting to add PC bit.");
    zos.changeExtAttr(path, zos.EXTATTR_PROGCTL, true);
    const success = hasPCBit(path);
    if (!success) {
      console.log("PC bit not set. This must be set such as by executing 'extattr +p $COMPONENT_HOME/lib/sys.so' as a user with sufficient privilege.");
    }
    return success;
  } else {
    return true;
  }
}

function hasPCBit(path: string): boolean {
  const returnArray = zos.zstat(path);
  if (!returnArray[1]) { //no error
    return returnArray[0].extattrs == zos.EXTATTR_PROGCTL
  } else {
    if (returnArray[1] != std.ENOENT) {
      console.log(`hasPCBit path=${path}, err=`,returnArray[1]);
    }
    return false;
  }
}


function checkZssPcBit(appfwPluginPath: string): void {
  const pluginDefinition = getPluginDefinition(appfwPluginPath);
  if (pluginDefinition) {
    if (pluginDefinition.dataServices) {
      console.log(`Checking ZSS services in plugin path=${appfwPluginPath}`);
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
    console.log(`Skipping ZSS PC bit check of plugin at ${appfwPluginPath} due to pluginDefinition missing or invalid`);
  }
}

function processZssPluginInstall(componentDir: string): void {
  if (os.platform == 'zos') {
    console.log(`- Checking for zss plugins and verifying them`);
    const manifest = getManifest(componentDir);
    if (manifest && manifest.appfwPlugins) {
      manifest.appfwPlugins.forEach(function(appfwPlugin: any) {
        const path = appfwPlugin.path;
        checkZssPcBit(`${componentDir}/${path}`);
      });
    }
  }
}



function processComponentAppfwPlugin(componentDir: string): boolean {
  const manifest = getManifest(componentDir);
  if (manifest && manifest.appfwPlugins) {
    manifest.appfwPlugins.forEach((appfwPlugin: any) => {
      const fullPath = `${componentDir}/appfwPlugin.path`;
      if (!fs.fileExists(`${fullPath}/pluginDefinition.json`)) {
        common.printError(`App Framework plugin directory ${fullPath} does not have pluginDefinition.json`);
        return false;
      }
      
      if (os.platform != 'zos') {
        const pluginDefinition = getPluginDefinition(fullPath);
        if (pluginDefinition && pluginDefinition.identifier) {
          const pluginDirsPath=`${workspaceDirectory}/app-server`;
          let rc = fs.mkdirp(`${workspaceDirectory}/app-server/pluginDirs/${pluginDefinition.identifier}`);
          if (rc) {
            common.printError(`Plugin registration failed because cannot make directory = ${workspaceDirectory}/app-server/pluginDirs/${pluginDefinition.identifier}`);
          }
          fs.cpr(`${fullPath}/.`, `${workspaceDirectory}/app-server/pluginDirs/${pluginDefinition.identifier}`);

          return registerPlugin(fullPath, pluginDefinition);
        } else {
          common.printError(`Cannot read identifier from App Framework plugin ${fullPath}/pluginDefinition.json`);
          return false;
        }
      }
    });
  }
  return true;
}

/*
 Parse and process manifest Gateway Shared Libs (gatewaySharedLibs) definitions

 The supported manifest entry is ".gatewaySharedLibs". All shared libs
 defined will be passed to install-app.sh for proper installation.
*/
const gatewaySharedLibs = std.getenv('ZWE_GATEWAY_SHARED_LIBS');
function processComponentGatewaySharedLibs(componentDir: string): boolean {
  fs.mkdirp(gatewaySharedLibs);

  const manifest = getManifest(componentDir);
  let pluginName;
  let gatewaySharedLibsWorkspacePath;
  
  if (manifest && manifest.gatewaySharedLibs) {
    manifest.gatewaySharedLibs.forEach((gatewaySharedLibsDef: any) => {
      const fileOrDir=`${componentDir}/${gatewaySharedLibsDef}`;
      if (!pluginName) {
        pluginName = manifest.name;
        if (!pluginName) {
          common.printError(`Cannot read name from the plugin ${componentDir}`);
          return false;
        }
        gatewaySharedLibsWorkspacePath = `${gatewaySharedLibs}/${pluginName}`;
        fs.mkdirp(gatewaySharedLibsWorkspacePath);
      }

      const manifestPath = getComponentManifest(componentDir);
      if (manifestPath) {
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
    });
  }
  return true;
}


/*
 Parse and process manifest Discovery Shared Libs (discoverySharedLibs) definitions

 The supported manifest entry is ".discoverySharedLibs". All shared libs
 defined will be passed to install-app.sh for proper installation.
*/
const discoverySharedLibs = std.getenv('ZWE_DISCOVERY_SHARED_LIBS');
function processComponentDiscoverySharedLibs(componentDir: string): boolean {
  fs.mkdirp(discoverySharedLibs);

  const manifest = getManifest(componentDir);
  let pluginName;
  let discoverySharedLibsWorkspacePath;
  
  if (manifest && manifest.discoverySharedLibs) {
    manifest.discoverySharedLibs.forEach((discoverySharedLibsDef: any) => {
      const fileOrDir=`${componentDir}/${discoverySharedLibsDef}`;
      if (!pluginName) {
        pluginName = manifest.name;
        if (!pluginName) {
          common.printError(`Cannot read name from the plugin ${componentDir}`);
          return false;
        }
        discoverySharedLibsWorkspacePath = `${discoverySharedLibs}/${pluginName}`;
        fs.mkdirp(discoverySharedLibsWorkspacePath);
      }

      const manifestPath = getComponentManifest(componentDir);
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
    });
  }
  return true;
}

const gatewayHost = std.getenv('ZWE_GATEWAY_HOST');
const haInstanceHostname = std.getenv('ZWE_haInstance_hostname');
const catalogPort = Number(std.getenv('ZWE_components_api_catalog_port'));
const zoweCertificatePemKey = std.getenv('ZWE_zowe_certificate_pem_key');
const zoweCertificatePemCertificate = std.getenv('ZWE_zowe_certificate_pem_certificate');
const zoweCertificatePemCertificateAuthorities = std.getenv('ZWE_zowe_certificate_pem_certificateAuthorities');
function refreshStaticRegistration(apimlcatalogHost: string=gatewayHost, apimlcatalogPort: number= catalogPort,
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
