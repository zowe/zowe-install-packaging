/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

// @ts-ignore
import * as std from 'std';
// @ts-ignore
import * as os from 'os';
// @ts-ignore
import { ConfigManager } from 'Configuration';


export const CONFIG_MGR = new ConfigManager();
CONFIG_MGR.setTraceLevel(0);

let parameterConfig = std.getenv('ZWE_CLI_PARAMETER_CONFIG');
const configPath = (parameterConfig && !parameterConfig.startsWith('FILE(')) ? `FILE(${parameterConfig})` : parameterConfig;
let configLoaded = false;

const COMMON_SCHEMA = `${std.getenv('ZWE_zowe_runtimeDirectory')}/schemas/server-common.json`;
const ZOWE_SCHEMA = `${std.getenv('ZWE_zowe_runtimeDirectory')}/schemas/zowe-yaml-schema.json`;
const ZOWE_SCHEMA_ID = 'https://zowe.org/schemas/v2/server-base';
const ZOWE_SCHEMA_SET=`${ZOWE_SCHEMA}:${COMMON_SCHEMA}`;

export const ZOWE_CONFIG=getZoweConfig();

export function getZoweConfig(): any {
  if (configLoaded) {
    return CONFIG_MGR.getConfigData('zowe-server-base');
  }
  
  if (configPath) {
    let status;

    if ((status = CONFIG_MGR.addConfig('zowe-server-base'))) {
      std.err.printf(`Could not add config for ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = CONFIG_MGR.loadSchemas('zowe-server-base', ZOWE_SCHEMA_SET))) {
      std.err.printf(`Could not load schemas ${ZOWE_SCHEMA_SET} for configs ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = CONFIG_MGR.setConfigPath('zowe-server-base', configPath))) {
      std.err.printf(`Could not set config path for ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = CONFIG_MGR.loadConfiguration('zowe-server-base'))) {
      std.err.printf(`Could not load config for ${configPath}, status=${status}`);
      std.exit(1);
    }

    let validation = CONFIG_MGR.validate('zowe-server-base');
    if (validation.ok){
      if (validation.exceptions){
        std.err.printf(`Validation of ${configPath} against schema ${ZOWE_SCHEMA_ID} found invalid JSON Schema data`);
        for (let i=0; i<validation.exceptions.length; i++){
          std.err.printf("    "+validation.exceptions[i]);
        }
        std.exit(1);
      } else {
        configLoaded = true;
        return CONFIG_MGR.getConfigData('zowe-server-base');
      }
    } else {
      std.err.printf(`Error occurred on validation of ${configPath} against schema ${ZOWE_SCHEMA_ID}<`);
      std.exit(1);
    }
  } else {
    std.err.printf(`Server config path not given`);
    std.exit(1);
  }  
}
