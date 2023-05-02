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

import * as common from './common';
import * as fs from './fs';
import * as stringlib from './string';
import * as shell from './shell';
import * as varlib from './var';
import * as configmgr from './configmgr';
import * as component from './component';
import * as zosfs from './zos-fs';
import * as sys from './sys';
import * as container from './container';
import * as node from './node';
import * as objUtils from '../utils/ObjUtils';

const cliParameterConfig:string = function() {
    let value = std.getenv('ZWE_CLI_PARAMETER_CONFIG');
    if (!value){
        std.out.printf("No ZWE_CLI_PARAMETER_CONFIG env var, exiting");
        std.exit(0);
    }
    return (value as string);
}();

const runtimeDirectory=configmgr.ZOWE_CONFIG.zowe.runtimeDirectory;
//const extensionDirectory=ZOWE_CONFIG.zowe.extensionDirectory;
const workspaceDirectory=configmgr.ZOWE_CONFIG.zowe.workspaceDirectory;

export function getZoweConfig(): any {
  return configmgr.ZOWE_CONFIG;
}

export function updateZoweConfig(updateObj: any, writeUpdate: boolean, arrayMergeStrategy: number): any {
  return configmgr.updateZoweConfig(updateObj, writeUpdate, arrayMergeStrategy);
}

// Convert instance.env to zowe.yaml file
export function convertInstanceEnvToYaml(instanceEnv: string, zoweYaml?: string) {
  // we need node for following commands
  node.ensureNodeIsOnPath();

  if (!zoweYaml) {
    shell.execSync('node', `${std.getenv('ROOT_DIR')}/bin/utils/config-converter/src/cli.js`, `env`, `yaml`, instanceEnv);
  } else {
    shell.execSync('node', `${std.getenv('ROOT_DIR')}/bin/utils/config-converter/src/cli.js`, `env`, `yaml`, instanceEnv, `-o`, zoweYaml);

    zosfs.ensureFileEncoding(zoweYaml, "zowe:", 1047);

    shell.execSync('chmod', `640`, zoweYaml);
  }
}

//////////////////////////////////////////////////////////////
// Check encoding of a file and convert to IBM-1047 if needed.
//
// Note: usually this is required if the file is supposed to be shell script,
//       which requires to be IBM-1047 encoding.
//
export function zosConvertEnvDirFileEncoding(file: string) {
  const encoding=zosfs.getFileEncoding(file);
  if (encoding && encoding != 0 && encoding != 1047) {
    const tmpfile=`${std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR')}/t`;
    os.remove(tmpfile);
    shell.execSync('sh', '-c', `iconv -f "${encoding}" -t "IBM-1047" "${file}" > "${tmpfile}"`);
    os.rename(tmpfile, file);
    shell.execSync('chmod', `640`, file);
    common.printTrace(`>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>AFTER ${file}`);
    const lsReturn = shell.execOutSync('ls', `-laT`, file);
    common.printTrace(lsReturn.out || "");
  }
}

// Prepare configuration for current HA instance, and generate backward
// compatible instance.env files from zowe.yaml.
//
export function generateInstanceEnvFromYamlConfig(haInstance: string) {
  let zwePrivateWorkspaceEnvDir = std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR');
  if (!zwePrivateWorkspaceEnvDir) {
    zwePrivateWorkspaceEnvDir=`${workspaceDirectory}/.env`
    std.setenv('zwePrivateWorkspaceEnvDir', zwePrivateWorkspaceEnvDir);
  }

  // delete old files to avoid potential issues
  common.printFormattedTrace( "ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `deleting old files under ${zwePrivateWorkspaceEnvDir}`);
  let foundFiles = fs.getFilesInDirectory(zwePrivateWorkspaceEnvDir);
  if (foundFiles) {
    foundFiles.forEach((file:string)=> {
      if (file.endsWith(".zowe.json")
          || file.endsWith(`-${haInstance}.env`)
          || file.endsWith(`-${haInstance}.json`)) {
        os.remove(zwePrivateWorkspaceEnvDir+'/'+file);
      }
    });
  }

  const components = component.findAllInstalledComponents2();
  //TODO use configmgr to write json and ha json, and components json
  
  // prepare .zowe.json and .zowe-<ha-id>.json
  common.printFormattedTrace("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `config-converter yaml convert --ha ${haInstance} ${cliParameterConfig}`);
  let result = shell.execOutSync('node', `${runtimeDirectory}/bin/utils/config-converter/src/cli.js`, `yaml`, `convert`, `--wd`, zwePrivateWorkspaceEnvDir, `--ha`, haInstance, cliParameterConfig, `--verbose`);

  common.printFormattedTrace("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `- Exit code: ${result.rc}: ${result.out}`);
  if ( !fs.fileExists(`${zwePrivateWorkspaceEnvDir}/.zowe.json`)) {
    common.printFormattedError( "ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `ZWEL0140E: Failed to translate Zowe configuration (${cliParameterConfig}).`);
    std.exit(140);
  }


  

  

  // convert YAML configurations to backward compatible .instance-<ha-id>.env files
  common.printFormattedTrace("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `config-converter yaml env --ha ${haInstance}`);
  const envs = configmgr.getZoweConfigEnv(haInstance);
  common.printFormattedTrace("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `- Output: ${JSON.stringify(envs, null, 2)}`);
  const envKeys = Object.keys(envs);
  let envFileArray=[];
  
  envFileArray.push('#!/bin/sh');
  envKeys.forEach((key:string)=> {
    envFileArray.push(`${key}=${envs[key]}`);
  });

  components.forEach((currentComponent:string)=> {
    const componentAlpha = stringlib.sanitizeAlpha(currentComponent);
    const componentDir = component.findComponentDirectory(currentComponent);
    const componentManifest = component.getManifest(componentDir);
    const folderName = `${zwePrivateWorkspaceEnvDir}/${currentComponent}`;
    let rc = fs.mkdirp(folderName, 0o700);
    if (rc) {
      //TODO error code
      common.printFormattedError("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `Failed to make env var folder for component=${currentComponent}`);
    }
    let componentFileArray = [];
    componentFileArray.push('#!/bin/sh');

    const componentConfigKeys = [];

    envKeys.forEach((key:string)=> {
      componentFileArray.push(`${key}=${envs[key]}`);
      if (key.startsWith(`ZWE_components_${componentAlpha}_`)) {
        const keyPrefixLength=`ZWE_components_${componentAlpha}_`.length;
        const configName = key.substring(keyPrefixLength);
        componentConfigKeys.push(configName);
      }
    });

    let flat = [];
    if (componentManifest.configs) {
      const flattener = new objUtils.Flattener();
      flattener.setSeparator('_');
      flattener.setKeepArrays(true);
      //flattener.setPrefix();
      flat = flattener.flatten(componentManifest.configs);
    }
    
    const flatKeys = Object.keys(flat);
    flatKeys.forEach((key: string)=> {
      if (componentConfigKeys.includes(key)) {
        //use it, and add it as _configs to component env
        componentFileArray.push(`ZWE_configs_${key}=${envs['ZWE_components_'+componentAlpha+'_'+key]}`);
      }  else {
        //use default, and add it as _configs, and also to envs
        componentFileArray.push(`ZWE_components_${componentAlpha}_${key}=${flat[key]}`);
        componentFileArray.push(`ZWE_configs_${key}=${flat[key]}`);
        
        envFileArray.push(`ZWE_components_${componentAlpha}_${key}=${flat[key]}`);
      }
    });
    
    componentConfigKeys.forEach((key: string)=> {
      if (!flatKeys.includes(key)) {
        //leftovers
        componentFileArray.push(`ZWE_configs_${key}=${envs['ZWE_components_'+componentAlpha+'_'+key]}`);
      }
    });
    
    const componentFileContent = componentFileArray.join('\n');
    rc = xplatform.storeFileUTF8(`${folderName}/.instance-${haInstance}.env`, xplatform.AUTO_DETECT, componentFileContent);
    if (rc) { 
      common.printFormattedError("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `ZWEL0140E: Failed to translate Zowe configuration (${cliParameterConfig}).`);
      std.exit(140);
      return;
    }
  });

  let envFileContent = envFileArray.join('\n');
  let rc = xplatform.storeFileUTF8(`${zwePrivateWorkspaceEnvDir}/.instance-${haInstance}.env`, xplatform.AUTO_DETECT, envFileContent);
  if (rc) {
    common.printFormattedError("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `ZWEL0140E: Failed to translate Zowe configuration (${cliParameterConfig}).`);
    std.exit(140);
    return;
  }
}


// check and sanitize ZWE_CLI_PARAMETER_HA_INSTANCE
export function sanitizeHaInstanceId(): string|undefined {
  // ignore default value passed from ZWESLSTC
  let zweCliParameterHaInstance = std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE');
  if (zweCliParameterHaInstance == "{{ha_instance_id}}" || zweCliParameterHaInstance == "__ha_instance_id__") {
    std.unsetenv('ZWE_CLI_PARAMETER_HA_INSTANCE');
    zweCliParameterHaInstance=undefined;
  }
  if (!zweCliParameterHaInstance) {
    zweCliParameterHaInstance=sys.getSysname();
  }
  // sanitize instance id
  if (zweCliParameterHaInstance){
    zweCliParameterHaInstance=stringlib.sanitizeAlphanum(zweCliParameterHaInstance.toLowerCase());
    std.setenv('ZWE_CLI_PARAMETER_HA_INSTANCE', zweCliParameterHaInstance );
  }
  return zweCliParameterHaInstance;
}

export function applyEnviron(environ: any): void {
  let keys = Object.keys(environ);
  keys.forEach(function(key:string) {
    common.printDebug(`applyEnviron setting ${key}=${environ[key]}`);
    std.setenv(key, environ[key]);
  });
}

//////////////////////////////////////////////////////////////
// Load environment variables used by components
//
// NOTE: all environment variables used/defined by Zowe should be ensured in this function.
//       "zwe internal start prepare" is the only special case where we may need to define some variables before calling
//       this function. The reason is to properly prepare the directories, logging, etc.
export function loadEnvironmentVariables(componentId?: string) {

  // check and sanitize zweCliParameterHaInstance
  sanitizeHaInstanceId();
  std.setenv('ZWE_zowe_workspaceDirectory',workspaceDirectory);

  if (!std.getenv('ZWE_VERSION')) {
// display starting information
    let manifestReturn = xplatform.loadFileUTF8(`${runtimeDirectory}/manifest.json`,xplatform.AUTO_DETECT);

    const runtimeManifest = manifestReturn ? JSON.parse(manifestReturn) : undefined;
    const zoweVersion = runtimeManifest ? runtimeManifest.version : undefined;
    std.setenv('ZWE_VERSION', zoweVersion);
  }

  // we must have $workspaceDirectory at this point
  if (fs.fileExists(`${workspaceDirectory}/.init-for-container`)) {
    std.setenv('ZWE_RUN_IN_CONTAINER','true');
  }

  // these are already set in prepare stage, re-ensure for start
  let zwePrivateWorkspaceEnvDir=`${workspaceDirectory}/.env`;
  std.setenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR', zwePrivateWorkspaceEnvDir);
  std.setenv('ZWE_STATIC_DEFINITIONS_DIR', `${workspaceDirectory}/api-mediation/api-defs`);
  std.setenv('ZWE_GATEWAY_SHARED_LIBS', `${workspaceDirectory}/gateway/sharedLibs/`);
  std.setenv('ZWE_DISCOVERY_SHARED_LIBS', `${workspaceDirectory}/discovery/sharedLibs/`);

  // now we can load all variables
  let zweCliParameterHaInstance=std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE');

  if (componentId && fs.fileExists(`${workspaceDirectory}/.env/${componentId}/.instance-${zweCliParameterHaInstance}.env`)) {
    varlib.sourceEnv(`${zwePrivateWorkspaceEnvDir}/${componentId}/.instance-${zweCliParameterHaInstance}.env`);
  } else if (fs.fileExists(`${zwePrivateWorkspaceEnvDir}/.instance-${zweCliParameterHaInstance}.env`)) {
    varlib.sourceEnv(`${zwePrivateWorkspaceEnvDir}/.instance-${zweCliParameterHaInstance}.env`);
  } else {
    common.printErrorAndExit( "Error ZWEL0112E: Zowe runtime environment must be prepared first with \"zwe internal start prepare\" command.", undefined, 112);
  }

  // ZWE_DISCOVERY_SERVICES_LIST should have been prepared in zowe-install-packaging-tools and had been sourced.

  // overwrite ZWE_PRIVATE_LOG_LEVEL_ZWELS with zowe.launchScript.logLevel config in YAML
  let logLevel =  configmgr.ZOWE_CONFIG.zowe.launchScript.logLevel;
  if (logLevel) {
    std.setenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS', logLevel.toUpperCase());
  }
  // generate other variables
  std.setenv('ZWE_INSTALLED_COMPONENTS', component.findAllInstalledComponents());
  std.setenv('ZWE_ENABLED_COMPONENTS', component.findAllEnabledComponents());
  std.setenv('ZWE_LAUNCH_COMPONENTS', component.findAllLaunchComponents());

  // ZWE_DISCOVERY_SERVICES_LIST should have been prepared in zowe-install-packaging-tools

  if (std.getenv('ZWE_RUN_IN_CONTAINER') == "true") {
    container.prepareContainerRuntimeEnvironments();
  }

  if (configmgr.ZOWE_CONFIG.zowe?.environments) {
    const environmentKeys = Object.keys(configmgr.ZOWE_CONFIG.zowe.environments);
    environmentKeys.forEach((key)=> {
      std.setenv(key, configmgr.ZOWE_CONFIG.zowe.environments[key]);
    });
  }
  
  return std.getenviron();
}
