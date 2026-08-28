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
import * as xplatform from 'xplatform';
import { ConfigManager } from 'Configuration';
import * as fs from './fs';
import * as stringlib from './string';
import * as common from './common';

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
std.setenv('ZWE_PRIVATE_CONFIG_ORIG', parameterConfig);
/*
  When using configmgr (--configmgr or zowe.useConfigmgr=true)
  the config property of Zowe can take a few shapes:
  1. a single path, ex /my/zowe.yaml
  2. one or more file paths with FILE() syntax, ex FILE(/my/1.yaml):FILE(/my2.yaml)
  3. one or more parmlib paths with PARMLIB() syntax, ex PARMLIB(my.zowe(yaml1)):PARMLIB(my.other.zowe(yaml2))
  4. one or more of FILE and PARMLIB syntax combined, ex FILE(/my/1.yaml):FILE(/my2.yaml):PARMLIB(my.zowe(yaml1)):PARMLIB(my.other.zowe(yaml2))
 */
const ZOWE_CONFIG_PATH = (parameterConfig && !parameterConfig.startsWith('FILE(') && !parameterConfig.startsWith('PARMLIB('))
                          ? `FILE(${parameterConfig}):FILE(${std.getenv('ZWE_zowe_runtimeDirectory')}/files/defaults.yaml)`
                          : parameterConfig + `:FILE(${std.getenv('ZWE_zowe_runtimeDirectory')}/files/defaults.yaml)`;
let configLoaded = false;

const COMMON_SCHEMA = `${std.getenv('ZWE_zowe_runtimeDirectory')}/schemas/server-common.json`;
const ZOWE_SCHEMA = `${std.getenv('ZWE_zowe_runtimeDirectory')}/schemas/zowe-yaml-schema.json`;
const ZOWE_SCHEMA_ID = 'https://zowe.org/schemas/v2/server-base';
const ZOWE_SCHEMA_SET=`${ZOWE_SCHEMA}:${COMMON_SCHEMA}`;

let ZOWE_CONFIG;
let HA_CONFIGS = {};

export function getFirstConfigFile() {
  let configPath = std.getenv('ZWE_PRIVATE_CONFIG_ORIG');
  if (!configPath) {
    configPath = std.getenv('ZWE_PRIVATE_CONFIG');
  }
  let configFile = configPath;
  if (!configFile.startsWith('/')) {
    configFile = configPath.split(':')[0];
  } else {
    configFile = 'FILE('+configFile+')';
  }

  return configFile;
}

export function getZoweConfig() {
  if (ZOWE_CONFIG == null) {
    ZOWE_CONFIG = loadZoweConfig();
  }
  return ZOWE_CONFIG
}

export function getZoweBaseSchemas(): string {
  return ZOWE_SCHEMA_SET;
}

function guaranteePath() {
  if (!std.getenv('PATH')) {
    std.setenv('PATH','/bin:.:/usr/bin');
  }
}

function getTempMergedYamlDir(): string|number {
  let zwePrivateWorkspaceEnvDir: string;
  let tmpDir = std.getenv('ZWE_PRIVATE_TMP_MERGED_YAML_DIR');
  if (tmpDir && tmpDir != '1') {
    zwePrivateWorkspaceEnvDir = tmpDir;
    return zwePrivateWorkspaceEnvDir;
  } else if (tmpDir == '1') {
    //If this var is not undefined,
    //A command is running that is likely to be an admin rather than STC user, so they wouldn't have .env folder permission
    //Instead, this merged yaml should be temporary within a place they can write to.
    let tmp = '';
    for (const dir of [std.getenv('TMPDIR'), std.getenv('TMP'), '/tmp']) {
      if (dir) {
        let dirWritable = false;
        let returnArray = os.stat(dir);
        if (!returnArray[1]) { //no error
          dirWritable = ((returnArray[0].mode & os.S_IFMT) == os.S_IFDIR)
        } else {
          if ((returnArray[1] != std.Error.ENOENT)) {
            console.log(`directoryExists dir=${dir}, err=`+returnArray[1]);
          }
        }

        if (dirWritable) {
          tmp = dir;
          break;
        } else {
          console.log(`Error ZWEL0110E: Doesn\'t have write permission on ${dir} directory.`);
          std.exit(110);
        }
      }
    }
    if (!tmp) {
      console.log(`Error: No writable temporary directory could be found, cannot continue`);
      std.exit(1);
    }
    
    zwePrivateWorkspaceEnvDir=`${tmp}/.zweenv-${Math.floor(Math.random()*10000)}`;
    std.setenv('ZWE_PRIVATE_TMP_MERGED_YAML_DIR', zwePrivateWorkspaceEnvDir);
    const mkdirrc = fs.mkdirp(zwePrivateWorkspaceEnvDir, 0o700);
    if (mkdirrc) { return mkdirrc; }

    if (!std.getenv('ZWE_CLI_PARAMETER_SILENT')) {
      console.log(`Temporary directory '${zwePrivateWorkspaceEnvDir}' created.\nZowe will remove it on success, but if zwe exits with a non-zero code manual cleanup would be needed.`);
    }
    return zwePrivateWorkspaceEnvDir;
  } else {
    return 0;
  }

}

function getDiscoveryServiceUrlHa(config) {
  const list = [];
  const defaultDs = config.components.discovery;
  const haInstanceKeys = Object.keys(config.haInstances);
  
  for (const haInstanceKey of haInstanceKeys) {
    const haInstance = config.haInstances[haInstanceKey];

    if (!haInstance.hostname) {
      console.log(`Error: 'hostname' value is missing for haInstance '${haInstanceKey}'`);
      if (haInstanceKeys.length == 1) {
        console.log(`Debug: Discovery server will be configured without HA`);
        return null;
      }
      std.exit(1);
    }

    const haInstanceDs = haInstance.components?.discovery;
    const enabled = haInstanceDs && (typeof haInstanceDs.enabled !== 'undefined') ? haInstanceDs.enabled : defaultDs.enabled;
    if (enabled !== true) continue;

    const port = haInstanceDs?.port ?? defaultDs.port;
    if (!port) {
      console.log(`Error: Missing configuration of diverery port, see 'components.discovery.port' or 'haInstances.${haInstanceKey}.components.discovery.port'`);
      std.exit(1);
    }

    const url = `https://${haInstance.hostname}:${port}/eureka/`;

    if (list.includes(url)) {
      console.log(`Warn: Multiple haInstances reffers to the same hostname: ${haInstance.hostname}`);
    } else {
      list.push(url);
    }

  }

  return list;
}

function getDiscoveryServiceUrlNonHa(config) {
  const list = [];
  if (config.components?.discovery?.enabled !== true) {
    return list;
  }

  const port = config.components?.discovery?.port;
  if (!port) {
    console.log(`Error: missing configuration 'components.discovery.port'`);
    std.exit(1);
  }

  config.zowe.externalDomains.forEach((domain: string) => {
    const url = `https://${domain}:${port}/eureka/`;
    if (list.includes(url)) {
      console.log(`Warn: External domains are not unique: ${domain}`);
    } else {
      list.push(url);
    }
  });

  return list;
}

function getDiscoveryServiceUrl(config) {
  if (config.haInstances) {
    const list = getDiscoveryServiceUrlHa(config);
    if (list) return list;
  }

  return getDiscoveryServiceUrlNonHa(config);
}

function getDefaultAllowedDomains(config) {
  const list: string[] = [];

  const externalDomains = config.zowe.externalDomains;
  const zosmfHost = config.zOSMF?.host;
  const listenAddresses = config.zowe.network?.server?.listenAddresses;
  
  if (config.haInstances) {
    const haInstanceKeys = Object.keys(config.haInstances);
    for (const haInstanceKey of haInstanceKeys) {
      const haInstance = config.haInstances[haInstanceKey];
  
      if (!haInstance.hostname) {
        console.log(`Error: 'hostname' value is missing for haInstance '${haInstanceKey}'`);

        std.exit(1);
      }
      list.push(haInstance.hostname);
    }
  }

  return Array.from(new Set([
    ...list,
    ...(externalDomains || []),
    ...(zosmfHost ? [zosmfHost] : []),
    ...(listenAddresses || []),
  ]));
}

function getAllowedDomains(config) {
  const defaults = getDefaultAllowedDomains(config);

  let allowedDomains = config.zowe.network.allowedDomains;
  
  const combined = [
    ...(defaults || []),
    ...allowedDomains || []
  ];

  return Array.from(new Set(
    combined
      .map(entry => entry.trim())
      .filter(entry => {
        if (entry.startsWith(',') || entry.endsWith(',')) {
          console.log(`Debug: Invalid domain: ${entry}`);
          return false;
        }
        return entry.length > 0;
      })
  ));
  
}

function writeZoweConfigUpdate(updateObj: any, arrayMergeStrategy: number, shouldValidate: boolean=true): number {
  let firstConfigPath = ZOWE_CONFIG_PATH.split(':')[0];

  if (!Number.isInteger(CONFIG_REVISIONS[firstConfigPath])) {
    // Initialize config before update
    getConfig(firstConfigPath, firstConfigPath, ZOWE_SCHEMA_SET);
  }
  
  let rc = updateConfig(firstConfigPath, updateObj, arrayMergeStrategy, shouldValidate);
  if (rc == 0) {
    let [ yamlStatus, textOrNull ] = CONFIG_MGR.writeYAML(getConfigRevisionName(firstConfigPath));
    if (yamlStatus === 0) {
      writeToCfgPath(firstConfigPath, textOrNull);
    }
  }
  return rc;
}

/**
 * Writes content to the zweCfgPath, which must be of style 'FILE(<path>)' or 'PARMLIB(<path>)'
 * 
 * @param zweCfgPath 
 * @param content 
 * @returns 
 */
function writeToCfgPath(zweCfgPath: string, content: string): any {
  let destination = zweCfgPath;
  let rc = 0;
  if (destination.startsWith('FILE(')) {
    destination = destination.substring(5, destination.length-1);
    return xplatform.storeFileUTF8(destination, xplatform.AUTO_DETECT, content);

  } else if (destination.startsWith('PARMLIB(')) {
    const isValidParmlib = common.isValidZoweYamlParmlib(destination);
    if (!isValidParmlib.ok) {
      common.printErrorAndExit(isValidParmlib.error.message, undefined, isValidParmlib.error.code);
    }
    destination = destination.substring(8, destination.length-1);
    let zwePrivateWorkspaceEnvDir: string;
    let dirResult = getTempMergedYamlDir();
    if (typeof dirResult == 'string') {
      zwePrivateWorkspaceEnvDir = dirResult;
    } else if (dirResult === 0) {
      const workspace = getZoweConfig().zowe.workspaceDirectory;

      //need a temp file to do the cp into parmlib
      //ensure .env folder exists
      zwePrivateWorkspaceEnvDir = std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR');
      if (!zwePrivateWorkspaceEnvDir) {
        zwePrivateWorkspaceEnvDir=`${workspace}/.env`;
        std.setenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR', zwePrivateWorkspaceEnvDir);
      }
      fs.mkdirp(workspace, 0o770);
      rc = fs.mkdirp(zwePrivateWorkspaceEnvDir, 0o700);
      if (rc) { return rc; }
    } else {
      return dirResult;
    }

    //make temp file
    let tempFilePath:string;
    let attempt=0;
    while (!tempFilePath) {
      let file = `${zwePrivateWorkspaceEnvDir}/zwe-parmlib-${Math.floor(Math.random()*10000)}`;

      let returnArray = os.stat(file);
      if (returnArray[1] === std.Error.ENOENT) {
        tempFilePath=file;
      }
      ++attempt;
      if (attempt>10000) {
        console.log(`Error: Could not update PARMLIB, could not make temporarily file in ${zwePrivateWorkspaceEnvDir}`);
        return 1;
      }
    }
    rc = xplatform.storeFileUTF8(tempFilePath, xplatform.AUTO_DETECT, content);
    if (rc) { return rc; }        
      
    const cpCommand=`cp -v "${tempFilePath}" "//'${stringlib.escapeDollar(destination)}'"`;
    console.log('Writing temp file for PARMLIB update. Command= '+cpCommand);
    rc = os.exec(['sh', '-c', cpCommand],
                  {block: true, usePath: true});
    if (rc != 0) {
      console.log(`Error: Could not write PARMLIB update into ${destination}, copy rc=${rc}`); 
    }
    const removeRc = os.remove(tempFilePath);
    if (removeRc !== 0) {
      console.log(`Error: Could not remove temporary file edit of ${destination} as ${tempFilePath}, rc=${removeRc}`);
    }
  }
}

export function cleanupTempDir() {
  const tmpDir = std.getenv('ZWE_PRIVATE_TMP_MERGED_YAML_DIR');
  if (tmpDir) {
    if (!std.getenv('PATH')) {
      std.setenv('PATH','/bin:.:/usr/bin');
    }
    const rc = os.exec(['rm', '-rf', tmpDir],
                       {block: true, usePath: true});
    if (rc != 0) {
      console.log(`Error: Temporary directory ${tmpDir} was not removed successfully, manual cleanup is needed. rc=${rc}`);
    }
  }
}

/**
 * Resolves the workspace .env directory used to write merged YAML files.
 * Returns the resolved directory path on success, or undefined on failure.
 */
function resolveWorkspaceEnvDir(workspace: string): string | undefined {
  const dirResult = getTempMergedYamlDir();
  if (typeof dirResult == 'string') {
    return dirResult;
  } else if (dirResult === 0) {
    let zwePrivateWorkspaceEnvDir = std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR');
    if (!zwePrivateWorkspaceEnvDir) {
      zwePrivateWorkspaceEnvDir = `${workspace}/.env`;
      std.setenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR', zwePrivateWorkspaceEnvDir);
    }
    fs.mkdirp(workspace, 0o770);
    const mkdirrc = fs.mkdirp(zwePrivateWorkspaceEnvDir, 0o700);
    if (mkdirrc) { return undefined; }
    return zwePrivateWorkspaceEnvDir;
  } else {
    return undefined;
  }
}

function writeMergedConfig(config: any, envDir: string): number {
  const destination = `${envDir}/.zowe-merged.yaml`;
  let [ yamlStatus, textOrNull ] = CONFIG_MGR.writeYAML(getConfigRevisionName(ZOWE_CONFIG_NAME));
  if (yamlStatus == 0){
    const rc = xplatform.storeFileUTF8(destination, xplatform.AUTO_DETECT, textOrNull);
    if (!rc) {
      std.setenv('ZWE_CLI_PARAMETER_CONFIG', destination);
    } else {
      console.log(`Error: Could not write .zowe-merged.yaml, ZWE_CLI_PARAMETER_CONFIG not modified!`);
      std.exit(1);
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

function deleteConfig(configName: string, deletePath: string, shouldValidate: boolean = true): number {
  let revision = CONFIG_REVISIONS[configName];
  if (!Number.isInteger(revision)) {
    console.log(`Error: Cannot update config if config not yet loaded`);
    return -1;
  }
  let currentName = getConfigRevisionName(configName, revision);
  revision++;
  let newName = getConfigRevisionName(configName, revision);
  let status = CONFIG_MGR.copyConfigurationAndDeleteKey(currentName, newName, deletePath);
  if (status == 0) {
    if (shouldValidate) {
      const validation = CONFIG_MGR.validate(newName);
      if (validation.ok) {
        if (validation.exceptionTree) {
          console.log(`Error: Validation of delete operation on ${configName} resulted in invalid JSON Schema data`);
          showExceptions(validation.exceptionTree, 0);
          return 1;
        } else {
          CONFIG_REVISIONS[configName]=revision;
          return status;
        }
      } else {
        console.log(`Error: Error occurred on validation of delete operation to ${configName}`);
      }
    } else {
      CONFIG_REVISIONS[configName]=revision;
      return status;
    }
  } else {
    console.log(`Error: Error occurred when deleting ${deletePath} from ${configName}`);
  }
  return status;
}

function updateConfig(configName: string, updateObj: any, arrayMergeStrategy: number=1, shouldValidate: boolean=true): number {
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
    if (shouldValidate) {
      const validation = CONFIG_MGR.validate(newName);
      if (validation.ok) {
        if (validation.exceptionTree) {
          console.log(`Error: Validation of update to ${configName} found invalid JSON Schema data`);
          showExceptions(validation.exceptionTree, 0);
          return 1;
        } else {
          CONFIG_REVISIONS[configName]=revision;
          return status;
        }
      } else {
        console.log(`Error: Error occurred on validation of update to ${configName}`);
        return 1;
      }
    } else {
      CONFIG_REVISIONS[configName]=revision;
      return status;
    }
  } else {
    console.log(`Error: Error occurred when making modified configuration of ${configName}`);
    return status;
  }
}

export function deleteFromZoweCfgFile(file: string, deleteKey: string, shouldValidate: boolean = true): [number, any] {
  const fileCfg = getConfigMgrSyntax(file);
  const zoweConfigName = 'zowe-delete-yaml';
  const ZOWE_FILE_CONFIG = getConfig(zoweConfigName, fileCfg, ZOWE_SCHEMA_SET, shouldValidate); 
  let rc = deleteConfig(zoweConfigName, deleteKey, shouldValidate);
  if (rc == 0){ 
    let [ yamlStatus, textOrNull ] = CONFIG_MGR.writeYAML(getConfigRevisionName(zoweConfigName));
    if (yamlStatus == 0) {
      writeToCfgPath(fileCfg, textOrNull);
    }
  }
  return [rc, ZOWE_FILE_CONFIG];
}

export function getConfigMgrSyntax(file: string): string {
  let cfgMgrFile = file;
  if (!file.startsWith('PARMLIB(') && !file.startsWith('FILE(')) {
    cfgMgrFile = `FILE(${file})`;
  }
  return cfgMgrFile;
}

export function updateZoweCfgFile(file: string, updateObj: any, arrayMergeStrategy: number=1, shouldValidate: boolean=true): [number, any] {
  const fileCfg = getConfigMgrSyntax(file);
  const zoweConfigName = 'zowe-update-yaml';
  const ZOWE_FILE_CONFIG = getConfig(zoweConfigName, fileCfg, ZOWE_SCHEMA_SET, shouldValidate); 
  let rc = updateConfig(zoweConfigName, updateObj, arrayMergeStrategy, shouldValidate);
  if (rc == 0){ 
    let [ yamlStatus, textOrNull ] = CONFIG_MGR.writeYAML(getConfigRevisionName(zoweConfigName));
    if (yamlStatus == 0) {
      writeToCfgPath(fileCfg, textOrNull);
    }
  }
  return [rc, ZOWE_FILE_CONFIG];
}

export function updateZoweConfig(updateObj: any, writeUpdate: boolean, arrayMergeStrategy: number=1, shouldValidate:boolean=true): [number, any] {
  let rc = updateConfig(getZoweConfigName(), updateObj, arrayMergeStrategy, shouldValidate);
  if (rc == 0) {
    ZOWE_CONFIG=loadZoweConfig();
    HA_CONFIGS = {}; //reset
    if (writeUpdate) {
      writeZoweConfigUpdate(updateObj, arrayMergeStrategy, shouldValidate);
      const dirOrErr = resolveWorkspaceEnvDir(ZOWE_CONFIG.zowe.workspaceDirectory);
      if (dirOrErr !== undefined) {
        writeMergedConfig(ZOWE_CONFIG, dirOrErr);
      }
    }
  }
  return [ rc, ZOWE_CONFIG ];
}

export function loadConfig(configName: string, configPath: string, schemas: string, shouldValidate: boolean = true) : any {
  return getConfig(configName, configPath, schemas, shouldValidate);
}

function getConfig(configName: string, configPath: string, schemas: string, shouldValidate: boolean = true): any {
  let configRevisionName = getConfigRevisionName(configName);
  if (Number.isInteger(CONFIG_REVISIONS[configName])) {
    //Already loaded
    return CONFIG_MGR.getConfigData(configRevisionName);
  }

  if (configPath) {
    let parts = configPath.split(':').filter((part) => part.trim().length > 0);
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i].trim();
      if (part.startsWith('PARMLIB(')) {
        const isValidParmlib = common.isValidZoweYamlParmlib(part);
        if (!isValidParmlib.ok) {
          common.printErrorAndExit(isValidParmlib.error.message, undefined, isValidParmlib.error.code);
        }
      }
    }
    
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

    if (shouldValidate) {
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
      const config = CONFIG_MGR.getConfigData(configRevisionName);
      if (!Number.isInteger(CONFIG_REVISIONS[configName])) {
        //loaded, mark revision 0
        CONFIG_REVISIONS[configName] = 0;
      }
      return config;
    }
  } else {
    console.log(`Error: Server config path not given`);
    std.exit(1);
  }
}

function makeHaConfig(haInstance: string, envDir: string): any {
  let config = getConfig(ZOWE_CONFIG_NAME, ZOWE_CONFIG_PATH, ZOWE_SCHEMA_SET);
  if (config.haInstances && config.haInstances[haInstance]) {
    let merger = new objUtils.Merger();
    merger.mergeArrays = false;
    let mergedConfig = merger.merge(config.haInstances[haInstance], config);
    INSTANCE_KEYS_NOT_IN_BASE.forEach((key) => delete mergedConfig[key]);
    HA_CONFIGS[haInstance] = mergedConfig;
    writeHaMergedConfig(haInstance, envDir);
    return mergedConfig;
  }
  return config;
}

/**
 * Writes a per-HA-instance merged YAML file to the workspace .env directory.
 * The result is a fully-resolved config for the given HA instance, with:
 *   - haInstance component/zowe overrides applied on top of the global config
 *   - the `haInstances` block is preserved so consumers (e.g. ZSS) can still
 *     inspect it (e.g. to count instances for cookie-name disambiguation).
 *
 * Output: <workspaceDirectory>/.env/.zowe-<haInstance>-merged.yaml
 *
 * @param haInstance  The HA instance name (e.g. "lpar1").
 * @param envDir      The already-resolved workspace .env directory (from resolveWorkspaceEnvDir),
 *                    passed in by the caller to avoid resolving it a second time.
 */
function writeHaMergedConfig(haInstance: string, envDir: string): number {
  const config = getConfig(ZOWE_CONFIG_NAME, ZOWE_CONFIG_PATH, ZOWE_SCHEMA_SET);
  if (!config.haInstances || !config.haInstances[haInstance]) {
    return 0; // no HA overrides for this instance, nothing to do
  }

  const zwePrivateWorkspaceEnvDir = envDir;

  // Build the override object from the haInstance entry, skipping instance-only keys
  // (hostname, sysname) since those don't belong at the root config level.
  const haInstanceData = config.haInstances[haInstance];
  const overrideObj: any = {};
  Object.keys(haInstanceData).forEach((key) => {
    if (!INSTANCE_KEYS_NOT_IN_BASE.includes(key)) {
      overrideObj[key] = haInstanceData[key];
    }
  });

  // Apply HA overrides on top of the base config via ConfigManager so we get a
  // properly-serialisable config revision (no schema validation needed here –
  // makeHaConfig already validated the merged result in memory).
  //
  // Use incrementing revision numbers (same pattern as updateConfig / deleteConfig) so that
  // repeated calls – e.g. after updateZoweConfig resets HA_CONFIGS – always allocate fresh
  // revision names and never try to re-create an already-registered ConfigManager revision.
  const haConfigName = `zowe-ha-${haInstance}`;
  const baseRevName  = getConfigRevisionName(ZOWE_CONFIG_NAME);

  // Initialise revision counter for this HA config name on first use.
  if (!Number.isInteger(CONFIG_REVISIONS[haConfigName])) {
    CONFIG_REVISIONS[haConfigName] = -1;
  }

  CONFIG_REVISIONS[haConfigName]++;
  const haOverrideRevName = getConfigRevisionName(haConfigName); // e.g. zowe-ha-lpar1_rev0, _rev2, ...

  let status = CONFIG_MGR.makeModifiedConfiguration(baseRevName, haOverrideRevName, overrideObj, 1);
  if (status != 0) {
    console.log(`Error: Could not apply HA instance overrides for '${haInstance}', rc=${status}`);
    return status;
  }

  // Write the overrides revision directly – haInstances is intentionally kept
  // so that consumers (e.g. ZSS generateCookieNameV2) can still count instances.
  let [yamlStatus, textOrNull] = CONFIG_MGR.writeYAML(haOverrideRevName);
  if (yamlStatus == 0) {
    const destination = `${zwePrivateWorkspaceEnvDir}/.zowe-${haInstance}-merged.yaml`;
    const rc = xplatform.storeFileUTF8(destination, xplatform.AUTO_DETECT, textOrNull);
    if (rc == 0) {
      console.log(`Debug: HA merged config for instance '${haInstance}' written to ${destination}`);
      // Expose the path so ZSS and other external consumers can locate the
      // instance-specific config without reconstructing the workspace path themselves.
      // Mirrors how writeMergedConfig sets ZWE_CLI_PARAMETER_CONFIG for the global config.
      std.setenv('ZWE_HA_INSTANCE_CONFIG', destination);
    } else {
      console.log(`Error: Could not write HA merged config to ${destination}, rc=${rc}`);
    }
    return rc;
  }
  return yamlStatus;
}

export function loadZoweConfig(haInstance?: string): any {
  if (configLoaded && !haInstance) {
    return getConfig(ZOWE_CONFIG_NAME, ZOWE_CONFIG_PATH, ZOWE_SCHEMA_SET);
  } else if (configLoaded) {
    const config = getConfig(ZOWE_CONFIG_NAME, ZOWE_CONFIG_PATH, ZOWE_SCHEMA_SET);
    const dirOrErr = resolveWorkspaceEnvDir(config.zowe.workspaceDirectory);
    if (dirOrErr === undefined) { return HA_CONFIGS[haInstance] || config; }
    return HA_CONFIGS[haInstance] || makeHaConfig(haInstance, dirOrErr);
  } else {
    let config = getConfig(ZOWE_CONFIG_NAME, ZOWE_CONFIG_PATH, ZOWE_SCHEMA_SET);
    configLoaded = true;
    const dirOrErr = resolveWorkspaceEnvDir(config.zowe.workspaceDirectory);
    if (dirOrErr === undefined) {
      console.log(`Error: Could not resolve workspace env dir`);
      std.exit(1);
    }
    const envDir = dirOrErr as string;
    writeMergedConfig(config, envDir);
    return haInstance ? makeHaConfig(haInstance, envDir) : config;
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
  let config = loadZoweConfig(haInstance);  // pass haInstance so makeHaConfig/writeHaMergedConfig is triggered
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
    overrides = haFlattener.flatten(config.haInstances[haInstance]);
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
    if (envs[key] != null) {
      envs[SPECIAL_ENV_MAPS[key]] = envs[key];
    }
  });



  //special things to keep as-is
  envs['ZWE_DISCOVERY_SERVICES_LIST'] = std.getenv('ZWE_DISCOVERY_SERVICES_LIST');
  if (!envs['ZWE_DISCOVERY_SERVICES_LIST']) {
    let list = getDiscoveryServiceUrl(config);
    envs['ZWE_DISCOVERY_SERVICES_LIST'] = list.join(',');
  }

  envs['ZWE_ALLOWED_DOMAINS'] = std.getenv('ZWE_ALLOWED_DOMAINS');
  if (!envs['ZWE_ALLOWED_DOMAINS']) {
    let list = getAllowedDomains(config);
    envs['ZWE_ALLOWED_DOMAINS'] = list.join(',');
  }

  envs['ZWE_haInstance_id'] = haInstance;

  // Propagate the HA instance merged config path to child processes (e.g. ZSS)
  // so they can locate the fully-resolved, instance-specific YAML without
  // reconstructing the workspace path themselves.
  const haInstanceConfig = std.getenv('ZWE_HA_INSTANCE_CONFIG');
  if (haInstanceConfig) {
    envs['ZWE_HA_INSTANCE_CONFIG'] = haInstanceConfig;
    console.log(`Info: HA instance merged config for '${haInstance}' is available at: ${haInstanceConfig}`);
  }

  return envs;
}
