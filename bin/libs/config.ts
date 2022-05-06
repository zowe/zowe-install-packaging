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
import * as common from './common';
import * as stringlib from './string';
import * as shell from './shell';

const runtimeDirectory=std.getenv('ZWE_zowe_runtimeDirectory');
const extensionDirectory=std.getenv('ZWE_zowe_extensionDirectory');
const workspaceDirectory=std.getenv('ZWE_zowe_workspaceDirectory');
let parameterConfig = std.getenv('ZWE_CLI_PARAMETER_CONFIG');
const configPath = (parameterConfig && !parameterConfig.startsWith('FILE(')) ? `FILE(${parameterConfig})` : parameterConfig;
let configLoaded = false;

const COMMON_SCHEMA = `${runtimeDirectory}/schemas/server-common.json`;
const ZOWE_SCHEMA = `${runtimeDirectory}/schemas/zowe-yaml-schema.json`;
const ZOWE_SCHEMA_ID = 'https://zowe.org/schemas/v2/server-base';
const ZOWE_SCHEMA_SET=`${ZOWE_SCHEMA}:${COMMON_SCHEMA}`;

function configMgrFailMessage(name:string) {
  common.printError('Failed to init config '+name);
  std.exit(1);
}


export function getZoweConfig(): any {
  if (configLoaded) {
    return common.CONFIG_MGR.getConfigData('zowe-server-base');
  }
  
  if (configPath) {
    let status;

    if ((status = common.CONFIG_MGR.addConfig('zowe-server-base'))) {
      common.printError(`Could not add config for ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = common.CONFIG_MGR.loadSchemas('zowe-server-base', ZOWE_SCHEMA_SET))) {
      common.printError(`Could not load schemas ${ZOWE_SCHEMA_SET} for configs ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = common.CONFIG_MGR.setConfigPath('zowe-server-base', configPath))) {
      common.printError(`Could not set config path for ${configPath}, status=${status}`);
      std.exit(1);
    }

    if ((status = common.CONFIG_MGR.loadConfiguration('zowe-server-base'))) {
      common.printError(`Could not load config for ${configPath}, status=${status}`);
      std.exit(1);
    }

    let validation = common.CONFIG_MGR.validate('zowe-server-base');
    if (validation.ok){
      if (validation.exceptions){
        common.printError(`Validation of ${configPath} against schema ${ZOWE_SCHEMA_ID} found invalid JSON Schema data`);
        for (let i=0; i<validation.exceptions.length; i++){
          common.printError("    "+validation.exceptions[i]);
        }
        std.exit(1);
      } else {
        configLoaded = true;
        return common.CONFIG_MGR.getConfigData('zowe-server-base');
      }
    } else {
      common.printError(`Error occurred on validation of ${configPath} against schema ${ZOWE_SCHEMA_ID} `);
      std.exit(1);
    }
  } else {
    common.printError(`Server config path not given`);
    std.exit(1);
  }
  
}
