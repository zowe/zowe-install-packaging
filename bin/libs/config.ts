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
import * as zosfs from './zosfs';
import * as fs from './fs';
import * as common from './common';
import * as stringlib from './string';
import * as shell from './shell';
import * as sys from './sys';
import * as component from './component';
import * as container from './container';
import * as varlib from './var';

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

// Convert instance.env to zowe.yaml file
export function convertInstanceEnvToYaml(instanceEnv: string, zoweYaml?: string) {
  // we need node for following commands
  node.ensureNodeIsOnPath();

  if (!zoweYaml) {
    shell.execSync('node', `${std.getenv('ROOT_DIR')}/bin/utils/config-converter/src/cli.js" env yaml "${instanceEnv}`);
  } else {
    shell.execSync('node', `${std.getenv('ROOT_DIR')}/bin/utils/config-converter/src/cli.js" env yaml "${instanceEnv}" -o "${zoweYaml}`);

    zosfs.ensureFileEncoding(zoweYaml, "zowe:", "IBM-1047");

    shell.execSync('chmod', `640 "${zoweYaml}"`);
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
  console.log( ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>BEFORE ${file} encoding is ${encoding}");
  console.log(std.loadFile(file));
  console.log( "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<");
  if (encoding && encoding != "UNTAGGED" && encoding != "IBM-1047") {
    const tmpfile=`${std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR')}/t`;
    os.remove(tmpfile);
    shell.execSync(`iconv`, `-f "${encoding}" -t "IBM-1047" "${file}" > "${tmpfile}"`);
    os.rename(tmpfile, file);
    shell.execSync('chmod', `640 "${file}"`);
    console.log(`>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>AFTER ${file}`);
    const lsReturn = shell.execOutSync('ls', `-laT "${file}"`);
    console.log(lsReturn.out);
    console.log(std.loadFile(file));
    console.log("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<");
  }
}

// Prepare configuration for current HA instance, and generate backward
// compatible instance.env files from zowe.yaml.
//
export function generateInstanceEnvFromYamlConfig(haInstance: string) {
  const workspaceDirectory=std.getenv('ZWE_zowe_workspaceDirectory');
  const runtimeDirectory=std.getenv('ZWE_zowe_runtimeDirectory');
  const zweCliParameterConfig = std.getenv('ZWE_CLI_PARAMETER_CONFIG');
  let zwePrivateWorkspaceEnvDir = std.getenv('zwePrivateWorkspaceEnvDir');
  if (!zwePrivateWorkspaceEnvDir) {
    zwePrivateWorkspaceEnvDir=`${workspaceDirectory}/.env`
    std.setenv('zwePrivateWorkspaceEnvDir', zwePrivateWorkspaceEnvDir);
  }

  // delete old files to avoid potential issues
  common.printFormattedTrace( "ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", "deleting old files under ${zwePrivateWorkspaceEnvDir}");
  shell.execSync('sh', `find "${zwePrivateWorkspaceEnvDir}" -type f -name ".*-${haInstance}.env" | xargs rm -f`);
  shell.execSync('sh', `find "${zwePrivateWorkspaceEnvDir}" -type f -name ".*-${haInstance}.json" | xargs rm -f`);
  shell.execSync('sh', `find "${zwePrivateWorkspaceEnvDir}" -type f -name ".zowe.json" | xargs rm -f`);

  // prepare .zowe.json and .zowe-<ha-id>.json
  common.printFormattedTrace("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `config-converter yaml convert --ha ${haInstance} ${zweCliParameterConfig}`);
  let result = shell.execOutSync('node', `${runtimeDirectory}/bin/utils/config-converter/src/cli.js" yaml convert --wd "${zwePrivateWorkspaceEnvDir}" --ha "${haInstance}" "${zweCliParameterConfig}" --verbose"`);

  common.printFormattedTrace("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `- Exit code: ${result.rc}: ${result.out}`);
  if ( !fs.fileExists(`${zwePrivateWorkspaceEnvDir}/.zowe.json`)) {
    common.printFormattedError( "ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `ZWEL0140E: Failed to translate Zowe configuration (${zweCliParameterConfig}).`);
    std.exit(140);
  }

  // convert YAML configurations to backward compatible .instance-<ha-id>.env files
  common.printFormattedTrace("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `config-converter yaml env --ha ${haInstance}`);
  result=shell.execOutSync('node', `"${runtimeDirectory}/bin/utils/config-converter/src/cli.js" yaml env --wd "${zwePrivateWorkspaceEnvDir}" --ha "${haInstance}" --verbose`);

  common.printFormattedTrace("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `- Exit code: ${result.rc}: ${result.out}`);
  
  if (!fs.fileExists("${zwePrivateWorkspaceEnvDir}/.instance-${haInstance}.env")) {
    common.printFormattedError("ZWELS", "bin/libs/config.sh,generate_instance_env_from_yaml_config", `ZWEL0140E: Failed to translate Zowe configuration (${zweCliParameterConfig}).`);
    std.exit(140);
  }
}


// check and sanitize ZWE_CLI_PARAMETER_HA_INSTANCE
export function sanitizeHaInstanceId() {
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
  zweCliParameterHaInstance=stringlib.sanitizeAlphanum(zweCliParameterHaInstance.toLowerCase());
  std.setenv('ZWE_CLI_PARAMETER_HA_INSTANCE', zweCliParameterHaInstance);
}

export function applyEnviron(environ: any): void {
  let keys = Object.keys(environ);
  keys.forEach(function(key:string) {
    std.setenv(key, environ[key]);
  });
}

//////////////////////////////////////////////////////////////
// Load environment variables used by components
//
// NOTE: all environment variables used/defined by Zowe should be ensured in this function.
//       "zwe internal start prepare" is the only special case where we may need to define some variables before calling
//       this function. The reason is to properly prepare the directories, logging, etc.
export function loadEnvironmentVariables(componentId: string) {

  // check and sanitize zweCliParameterHaInstance
  sanitizeHaInstanceId();
  let workspaceDirectory=std.getenv('ZWE_zowe_workspaceDirectory');
  if (!workspaceDirectory) {
    let zoweConfig = getZoweConfig();
    workspaceDirectory=zoweConfig.zowe.workspaceDirectory;
    std.setenv('ZWE_zowe_workspaceDirectory',workspaceDirectory);
  }

  if (!std.getenv('ZWE_VERSION')) {
    const runtimeManifestString=std.loadFile(`${runtimeDirectory}/manifest.json`);
    if (runtimeManifestString) {
      std.setenv('ZWE_VERSION', JSON.parse(runtimeManifestString).version);
    }
  }

  // we must have $workspaceDirectory at this point
  if (fs.fileExists(`${workspaceDirectory}/.init-for-container`)) {
    std.setenv('ZWE_RUN_IN_CONTAINER','true');
  }

  // these are already set in prepare stage, re-ensure for start
  std.setenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR', `${workspaceDirectory}/.env`);
  std.setenv('ZWE_STATIC_DEFINITIONS_DIR', `${workspaceDirectory}/api-mediation/api-defs`);
  std.setenv('ZWE_GATEWAY_SHARED_LIBS', `${workspaceDirectory}/gateway/sharedLibs/`);
  std.setenv('ZWE_DISCOVERY_SHARED_LIBS', `${workspaceDirectory}/discovery/sharedLibs/`);

  // now we can load all variables
  let zweCliParameterHaInstance=std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE');
  let zwePrivateWorkspaceEnvDir=std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR');    
  if (componentId && fs.fileExists(`${workspaceDirectory}/.env/${componentId}/.instance-${zweCliParameterHaInstance}.env`)) {
    varlib.sourceEnv(`${zwePrivateWorkspaceEnvDir}/${componentId}/.instance-${zweCliParameterHaInstance}.env`);
  } else if (fs.fileExists(`${zwePrivateWorkspaceEnvDir}/.instance-${zweCliParameterHaInstance}.env`)) {
    varlib.sourceEnv(`${zwePrivateWorkspaceEnvDir}/.instance-${zweCliParameterHaInstance}.env`);
  } else {
    common.printErrorAndExit( "Error ZWEL0112E: Zowe runtime environment must be prepared first with \"zwe internal start prepare\" command.", undefined, 112);
  }

  // ZWE_DISCOVERY_SERVICES_LIST should have been prepared in zowe-install-packaging-tools and had been sourced.

  // overwrite ZWE_PRIVATE_LOG_LEVEL_ZWELS with zowe.launchScript.logLevel config in YAML
  let logLevel =  std.getenv('ZWE_zowe_launchScript_logLevel');
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
  return std.getenviron();
}
