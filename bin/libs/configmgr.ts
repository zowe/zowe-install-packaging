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
import * as xplatform from 'xplatform';
import { ConfigManager } from 'Configuration';

import * as objUtils from '../utils/ObjUtils';

declare namespace console {
  function log(...args:string[]): void;
};

const ZOWE_CONFIG_NAME = 'zowe-server-base';
const CONFIG_REVISIONS = {};

export const CONFIG_MGR = new ConfigManager();
CONFIG_MGR.setTraceLevel(0);

//these show the list of files used for zowe config prior to merging into a unified one.
// ZWE_CLI_PARAMETER_CONFIG gets updated to point to the unified one once written.
const parameterConfig = std.getenv('ZWE_CLI_PARAMETER_CONFIG');
const ZOWE_CONFIG_PATH = (parameterConfig && !parameterConfig.startsWith('FILE(')) ? `FILE(${parameterConfig})` : parameterConfig;
let configLoaded = false;

const COMMON_SCHEMA = `${std.getenv('ZWE_zowe_runtimeDirectory')}/schemas/server-common.json`;
const ZOWE_SCHEMA = `${std.getenv('ZWE_zowe_runtimeDirectory')}/schemas/zowe-yaml-schema.json`;
const ZOWE_SCHEMA_ID = 'https://zowe.org/schemas/v2/server-base';
const ZOWE_SCHEMA_SET=`${ZOWE_SCHEMA}:${COMMON_SCHEMA}`;

export let ZOWE_CONFIG=getZoweConfig();

function mkdirp(path:string, mode?: number): number {
  const parts = path.split('/');
  let dir = '/';
  for (let i = 0; i < parts.length; i++) {
    dir+=parts[i]+'/';
    let rc = os.mkdir(dir, mode ? mode : 0o777);
    if (rc && (rc!=(0-std.Error.EEXIST))) {
      return rc;
    }
  }
  return 0;
}

function writeZoweConfigUpdate(updateObj: any, arrayMergeStrategy: number): number {
  let firstConfigPath = ZOWE_CONFIG_PATH.split(':')[0];

  if (!Number.isInteger(CONFIG_REVISIONS[firstConfigPath])) {
    // Initialize config before update
    getConfig(firstConfigPath, firstConfigPath, ZOWE_SCHEMA_SET);
  }
  
  let rc = updateConfig(firstConfigPath, updateObj, arrayMergeStrategy);
  if (rc == 0) {
    let [ yamlStatus, textOrNull ] = CONFIG_MGR.writeYAML(getConfigRevisionName(firstConfigPath));
    if (yamlStatus === 0) {
      let destination = firstConfigPath;
      if (destination.startsWith('FILE(')) {
        destination = destination.substring(5, destination.length-1);
      } else if (destination.startsWith('LIB(')) {
        console.log(`Error: LIB writing not yet implemented`);
        return -1;
      }
      return xplatform.storeFileUTF8(destination, xplatform.AUTO_DETECT, textOrNull);
    }
  }
  return rc;
}

function writeMergedConfig(config: any): number {
  const workspace = config.zowe.workspaceDirectory;
  let zwePrivateWorkspaceEnvDir = std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR');
  if (!zwePrivateWorkspaceEnvDir) {
    zwePrivateWorkspaceEnvDir=`${workspace}/.env`;
    std.setenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR', zwePrivateWorkspaceEnvDir);
  }
  mkdirp(workspace, 0o770);
  const mkdirrc = mkdirp(zwePrivateWorkspaceEnvDir, 0o700);
  if (mkdirrc) { return mkdirrc; }
  const destination = `${zwePrivateWorkspaceEnvDir}/.zowe-merged.yaml`;
  const jsonDestination = `${zwePrivateWorkspaceEnvDir}/.zowe.json`;
/*
  const jsonRC = xplatform.storeFileUTF8(jsonDestination, xplatform.AUTO_DETECT, JSON.stringify(ZOWE_CONFIG, null, 2));
  if (jsonRC) {
    console.log(`Error: Could not write json ${jsonDestination}, rc=${jsonRC}`);
  }
*/
  //const yamlReturn = CONFIG_MGR.writeYAML(getConfigRevisionName(ZOWE_CONFIG_NAME), destination);
  let [ yamlStatus, textOrNull ] = CONFIG_MGR.writeYAML(getConfigRevisionName(ZOWE_CONFIG_NAME));
  if (yamlStatus == 0){
    const rc = xplatform.storeFileUTF8(destination, xplatform.AUTO_DETECT, textOrNull);
    if (!rc) {
      std.setenv('ZWE_CLI_PARAMETER_CONFIG', destination);
    }
    return rc;
  }
  return yamlStatus;
}

function showExceptions(e: any,depth: number): void {
  let blanks = "                                                                 ";
  let subs = e.subExceptions;
  console.log(blanks.substring(0,depth*2)+e.message);
  if (subs){
    for (const sub of subs){
      showExceptions(sub,depth+1);
    }
  }
}


export function getZoweConfigName(): string {
  return ZOWE_CONFIG_NAME;
}

function getConfigRevisionName(configName: string, revision?: number): string {
  if (revision ===undefined) { revision = CONFIG_REVISIONS[configName] || 0;}
  return configName+'_rev'+revision;
}

function updateConfig(configName: string, updateObj: any, arrayMergeStrategy: number=1): number {
  let revision = CONFIG_REVISIONS[configName];
  if (!Number.isInteger(revision)) {
    console.log(`Error: Cannot update config if config not yet loaded`);
    return -1;
  }
  let currentName = getConfigRevisionName(configName, revision);
  revision++;
  let newName = getConfigRevisionName(configName, revision);
  let status = CONFIG_MGR.makeModifiedConfiguration(currentName, newName, updateObj, arrayMergeStrategy);
  if (status == 0) {
    const validation = CONFIG_MGR.validate(newName);
    if (validation.ok) {
      if (validation.exceptionTree) {
        console.log(`Error: Validation of update to ${configName} found invalid JSON Schema data`);
        showExceptions(validation.exceptionTree, 0);
      } else {
        CONFIG_REVISIONS[configName]=revision;
        return status;
      }
    } else {
      console.log(`Error: Error occurred on validation of update to ${configName}`);
    }
  } else {
    console.log(`Error: Error occurred when making modified configuration of ${configName}`);
  }
  return status;
}

export function updateZoweConfig(updateObj: any, writeUpdate: boolean, arrayMergeStrategy: number=1): [number, any] {
  let rc = updateConfig(getZoweConfigName(), updateObj, arrayMergeStrategy);
  if (rc == 0) {
    ZOWE_CONFIG=getZoweConfig();
    if (writeUpdate) {
      writeZoweConfigUpdate(updateObj, arrayMergeStrategy);
      writeMergedConfig(ZOWE_CONFIG);
    }
  }
  return [ rc, ZOWE_CONFIG ];
}
  
function getConfig(configName: string, configPath: string, schemas: string): any {
  let configRevisionName = getConfigRevisionName(configName);
  if (Number.isInteger(CONFIG_REVISIONS[configName])) {
    //Already loaded
    return CONFIG_MGR.getConfigData(configRevisionName);
  }
  
  if (configPath) {
    let status;

    if ((status = CONFIG_MGR.addConfig(configRevisionName))) {
      console.log(`Error: Could not add config for ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = CONFIG_MGR.loadSchemas(configRevisionName, schemas))) {
      console.log(`Error: Could not load schemas ${schemas} for configs ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = CONFIG_MGR.setConfigPath(configRevisionName, configPath))) {
      console.log(`Error: Could not set config path for ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = CONFIG_MGR.loadConfiguration(configRevisionName))) {
      console.log(`Error: Could not load config for ${configPath}, status=${status}`);
      std.exit(1);
    }

    let validation = CONFIG_MGR.validate(configRevisionName);
    if (validation.ok){
      if (validation.exceptionTree){
        console.log(`Error: Validation of ${configPath} against schema ${schemas} found invalid JSON Schema data`);
        showExceptions(validation.exceptionTree, 0);
        std.exit(1);
      } else {
        const config = CONFIG_MGR.getConfigData(configRevisionName);
        if (!Number.isInteger(CONFIG_REVISIONS[configName])) {
          //loaded, mark revision 0
          CONFIG_REVISIONS[configName] = 0;
        }
        return config;
      }
    } else {
      console.log(`Error: Error occurred on validation of ${configPath} against schema ${schemas}`);
      std.exit(1);
    }
  } else {
    console.log(`Error: Server config path not given`);
    std.exit(1);
  }  
}

export function getZoweConfig(): any {
  if (configLoaded) {
    return getConfig(ZOWE_CONFIG_NAME, ZOWE_CONFIG_PATH, ZOWE_SCHEMA_SET);
  } else {
    let config = getConfig(ZOWE_CONFIG_NAME, ZOWE_CONFIG_PATH, ZOWE_SCHEMA_SET);
    configLoaded = true;
    const writeResult = writeMergedConfig(config);
    return config;
  }
}

const SPECIAL_ENV_MAPS = {
  ZWE_node_home: 'NODE_HOME',
  ZWE_java_home:'JAVA_HOME',
  ZWE_zOSMF_host: 'ZOSMF_HOST',
  ZWE_zOSMF_port: 'ZOSMF_PORT',
  ZWE_zOSMF_applId: 'ZOSMF_APPLID'
};

const INSTANCE_KEYS_NOT_IN_BASE = [
  'hostname', 'sysname'
];

const keyNameRegex = /[^a-zA-Z0-9]/g;
export function getZoweConfigEnv(haInstance: string): any {
  let config = getZoweConfig();
  let flattener = new objUtils.Flattener();
  flattener.setSeparator('_');
  flattener.setPrefix('ZWE_');
  flattener.setKeepArrays(true);
  let envs = flattener.flatten(config);
  let overrides;
  if (config.haInstances && config.haInstances[haInstance]) {
    envs['ZWE_haInstance_hostname'] = config.haInstances[haInstance].hostname;
    const haFlattener = new objUtils.Flattener();
    haFlattener.setSeparator('_');
    haFlattener.setPrefix('ZWE_');
    haFlattener.setKeepArrays(true);
    let overrides = haFlattener.flatten(config.haInstances[haInstance]);
  } else {
    envs['ZWE_haInstance_hostname'] = config.zowe.externalDomains[0];
  }

  
  //env var key name sanitization
  let keys = Object.keys(envs);
  keys.forEach((key:string)=> {
    const newKey = key.replace(keyNameRegex, '_');
    if (key != newKey) {
      envs[newKey]=envs[key];
      delete envs[key];
    }
  });
  
  if (overrides) {
    let overrideKeys = Object.keys(overrides);
    overrideKeys.forEach((overrideKey:string)=> {
      const newKey = overrideKey.replace(keyNameRegex, '_');
      if (overrideKey != newKey) {
        overrides[newKey]=overrides[overrideKey];
        delete overrides[overrideKey];
      }
      if (!INSTANCE_KEYS_NOT_IN_BASE.includes(newKey)) {
        envs[newKey]=overrides[newKey];
      }
    });
  }

  let specialKeys = Object.keys(SPECIAL_ENV_MAPS);
  specialKeys.forEach((key:string)=> {
    envs[SPECIAL_ENV_MAPS[key]] = envs[key];
  });



  //special things to keep as-is
  envs['ZWE_DISCOVERY_SERVICES_LIST'] = std.getenv('ZWE_DISCOVERY_SERVICES_LIST');
  if (!envs['ZWE_DISCOVERY_SERVICES_LIST']) {
    let list = [];
    if (config.components.discovery && (config.components.discovery.enabled === true)) {
      const port = config.components.discovery.port;
      config.zowe.externalDomains.forEach((domain:string)=> {
        const url = `https://${domain}:${port}/eureka/`;
        if (!list.includes(url)) {
          list.push(url);
        }
      });
    }

    if (config.haInstances) {
      let haInstanceKeys = Object.keys(config.haInstances);
      haInstanceKeys.forEach((haInstanceKey:string)=> {
        const haInstance = config.haInstances[haInstanceKey];
        if (haInstance.hostname && haInstance.components && haInstance.components.discovery && (haInstance.components.discovery.enabled === true)) {
          const port = haInstance.components.discovery.port;
          const url = `https://${haInstance.hostname}:${port}/eureka/`;
          if (!list.includes(url)) {
            list.push(url);
          }
        }
      });
    }

    envs['ZWE_DISCOVERY_SERVICES_LIST'] = list.join(',');
  }

  envs['ZWE_haInstance_id'] = haInstance;
  
  return envs;
}
