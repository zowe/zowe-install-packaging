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

export const CONFIG_MGR = new ConfigManager();
CONFIG_MGR.setTraceLevel(0);

//these show the list of files used for zowe config prior to merging into a unified one.
// ZWE_CLI_PARAMETER_CONFIG gets updated to point to the unified one once written.
const parameterConfig = std.getenv('ZWE_CLI_PARAMETER_CONFIG');
const configPath = (parameterConfig && !parameterConfig.startsWith('FILE(')) ? `FILE(${parameterConfig})` : parameterConfig;
let configLoaded = false;

const COMMON_SCHEMA = `${std.getenv('ZWE_zowe_runtimeDirectory')}/schemas/server-common.json`;
const ZOWE_SCHEMA = `${std.getenv('ZWE_zowe_runtimeDirectory')}/schemas/zowe-yaml-schema.json`;
const ZOWE_SCHEMA_ID = 'https://zowe.org/schemas/v2/server-base';
const ZOWE_SCHEMA_SET=`${ZOWE_SCHEMA}:${COMMON_SCHEMA}`;

export const ZOWE_CONFIG=getZoweConfig();

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

function writeMergedConfig(config: any): number {
  const workspace = config.zowe.workspaceDirectory;
  let zwePrivateWorkspaceEnvDir = std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR');
  if (!zwePrivateWorkspaceEnvDir) {
    zwePrivateWorkspaceEnvDir=`${workspace}/.env`;
    std.setenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR', zwePrivateWorkspaceEnvDir);
  }
  const mkdirrc = mkdirp(zwePrivateWorkspaceEnvDir);
  if (mkdirrc) { return mkdirrc; }
  const destination = `${zwePrivateWorkspaceEnvDir}/.zowe-merged.yaml`;
  //const yamlReturn = CONFIG_MGR.writeYAML('zowe-server-base', destination);
  let [ yamlStatus, textOrNull ] = CONFIG_MGR.writeYAML('zowe-server-base');
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

export function getZoweConfig(): any {
  if (configLoaded) {
    return CONFIG_MGR.getConfigData('zowe-server-base');
  }
  
  if (configPath) {
    let status;

    if ((status = CONFIG_MGR.addConfig('zowe-server-base'))) {
      console.log(`Error: Could not add config for ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = CONFIG_MGR.loadSchemas('zowe-server-base', ZOWE_SCHEMA_SET))) {
      console.log(`Error: Could not load schemas ${ZOWE_SCHEMA_SET} for configs ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = CONFIG_MGR.setConfigPath('zowe-server-base', configPath))) {
      console.log(`Error: Could not set config path for ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = CONFIG_MGR.loadConfiguration('zowe-server-base'))) {
      console.log(`Error: Could not load config for ${configPath}, status=${status}`);
      std.exit(1);
    }

    let validation = CONFIG_MGR.validate('zowe-server-base');
    if (validation.ok){
      if (validation.exceptionTree){
        console.log(`Error: Validation of ${configPath} against schema ${ZOWE_SCHEMA_ID} found invalid JSON Schema data`);
        showExceptions(validation.exceptionTree, 0);
        std.exit(1);
      } else {
        configLoaded = true;
        
        const config = CONFIG_MGR.getConfigData('zowe-server-base');
        const writeResult = writeMergedConfig(config);
        return config;
      }
    } else {
      console.log(`Error: Error occurred on validation of ${configPath} against schema ${ZOWE_SCHEMA_ID}<`);
      std.exit(1);
    }
  } else {
    console.log(`Error: Server config path not given`);
    std.exit(1);
  }  
}

const SPECIAL_ENV_MAPS = {
  ZWE_node_home: 'NODE_HOME',
  ZWE_java_home:'JAVA_HOME',
  ZWE_zOSMF_host: 'ZOSMF_HOST',
  ZWE_zOSMF_port: 'ZOSMF_PORT',
  ZWE_zOSMF_applId: 'ZOSMF_APPLID'
};

// TODO haInstance values should be overriding the base values
const keyNameRegex = /[^a-zA-Z0-9]/g;
export function getZoweConfigEnv(haInstance?: string): any {
  let config = getZoweConfig();
  let flattener = new objUtils.Flattener();
  flattener.setSeparator('_');
  flattener.setPrefix('ZWE_');
  let envs = flattener.flatten(config);

  //env var key name sanitization
  let keys = Object.keys(envs);
  keys.forEach((key:string)=> {
    const newKey = key.replace(keyNameRegex, '_');
    if (key != newKey) {
      envs[newKey]=envs[key];
      delete envs[key];
    }
  });

  let specialKeys = Object.keys(SPECIAL_ENV_MAPS);
  specialKeys.forEach((key:string)=> {
    envs[SPECIAL_ENV_MAPS[key]] = envs[key];
  });



  //special things to keep as-is
  envs['ZWE_DISCOVERY_SERVICES_LIST'] = std.getenv('ZWE_DISCOVERY_SERVICES_LIST');
  
  return envs;
}
