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

import * as objUtils from '../utils/ObjUtils';

export type ZoweConfig = { [key: string]: any };
export type ComponentManifest = { [key: string]: any };

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

/*
  When using configmgr (--configmgr or zowe.useConfigmgr=true)
  the config property of Zowe can take a few shapes:
  1. a single path, ex /my/zowe.yaml
  2. one or more file paths with FILE() syntax, ex FILE(/my/1.yaml):FILE(/my2.yaml)
  3. one or more parmlib paths with PARMLIB() syntax, ex PARMLIB(my.zowe(yaml)):PARMLIB(my.other.zowe(yaml)) ... note the member names must be the same for every PARMLIB mentioned!
  4. one or more of FILE and PARMLIB syntax combined, ex FILE(/my/1.yaml):FILE(/my2.yaml):PARMLIB(my.zowe(yaml)):PARMLIB(my.other.zowe(yaml))
 */
const ZOWE_CONFIG_PATH = (parameterConfig && !parameterConfig.startsWith('FILE(') && !parameterConfig.startsWith('PARMLIB(')) ? `FILE(${parameterConfig})` : parameterConfig;
let configLoaded = false;

const COMMON_SCHEMA = `${std.getenv('ZWE_zowe_runtimeDirectory')}/schemas/server-common.json`;
const ZOWE_SCHEMA = `${std.getenv('ZWE_zowe_runtimeDirectory')}/schemas/zowe-yaml-schema.json`;
const ZOWE_SCHEMA_ID = 'https://zowe.org/schemas/v2/server-base';
const ZOWE_SCHEMA_SET=`${ZOWE_SCHEMA}:${COMMON_SCHEMA}`;

export let ZOWE_CONFIG=getZoweConfig();

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

    console.log(`Temporary directory '${zwePrivateWorkspaceEnvDir}' created.\nZowe will remove it on success, but if zwe exits with a non-zero code manual cleanup would be needed.`);
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

function writeZoweConfigUpdate(updateObj: ZoweConfig, arrayMergeStrategy: number): number {
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
        return xplatform.storeFileUTF8(destination, xplatform.AUTO_DETECT, textOrNull);

      } else if (destination.startsWith('PARMLIB(')) {
        destination = destination.substring(8, destination.length-1);

        let zwePrivateWorkspaceEnvDir: string;
        let dirResult = getTempMergedYamlDir();
        if (typeof dirResult == 'string') {
          zwePrivateWorkspaceEnvDir = dirResult;
        } else if (dirResult === 0) {
          const workspace = ZOWE_CONFIG.zowe.workspaceDirectory;

          //need a temp file to do the cp into parmlib
          //ensure .env folder exists
          let zwePrivateWorkspaceEnvDir = std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR');
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
        rc = xplatform.storeFileUTF8(tempFilePath, xplatform.AUTO_DETECT, textOrNull);
        if (rc) { return rc; }        
          
        const cpCommand=`cp -v "${tempFilePath}" "//'${destination}'"`;
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
  }
  return rc;
}

export function cleanupTempDir() {
  const tmpDir = std.getenv('ZWE_PRIVATE_TMP_MERGED_YAML_DIR');
  if (tmpDir) {
    if (!std.getenv('PATH')) {
      std.setenv('PATH','/bin:.:/usr/bin');
    }
    const rc = os.exec(['rm', '-rf', tmpDir],
                       {block: true, usePath: true});
    if (rc == 0) {
      console.log(`Temporary directory ${tmpDir} removed successfully.`);
    } else {
      console.log(`Error: Temporary directory ${tmpDir} was not removed successfully, manual cleanup is needed. rc=${rc}`);
    }
  }
}

function writeMergedConfig(config: ZoweConfig, componentId?: string, configName:string=ZOWE_CONFIG_NAME): {rc: number, path?: string} {
  const workspace = config.zowe.workspaceDirectory;

  let zwePrivateWorkspaceEnvDir: string;
  let dirResult = getTempMergedYamlDir();
  if (typeof dirResult == 'string') {
    zwePrivateWorkspaceEnvDir = dirResult;
  } else if (dirResult === 0) {
    zwePrivateWorkspaceEnvDir = std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR');
    if (!zwePrivateWorkspaceEnvDir) {
      zwePrivateWorkspaceEnvDir=`${workspace}/.env`;
      std.setenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR', zwePrivateWorkspaceEnvDir);
    }
    //but, components get subfolders.
    if (componentId) {
      zwePrivateWorkspaceEnvDir+=`/${componentId}`;
    }

    fs.mkdirp(workspace, 0o770);
    const mkdirrc = fs.mkdirp(zwePrivateWorkspaceEnvDir, 0o700);
    if (mkdirrc) { return {rc: mkdirrc}; }
  } else {
    return {rc: dirResult};
  }
  
  const destination = `${zwePrivateWorkspaceEnvDir}/.zowe-merged.yaml`;
  /* We don't write it in JSON, but we could!
  const jsonDestination = `${zwePrivateWorkspaceEnvDir}/.zowe.json`;
  const jsonRC = xplatform.storeFileUTF8(jsonDestination, xplatform.AUTO_DETECT, JSON.stringify(ZOWE_CONFIG, null, 2));
  if (jsonRC) {
    console.log(`Error: Could not write json ${jsonDestination}, rc=${jsonRC}`);
  }
  */
  //const yamlReturn = CONFIG_MGR.writeYAML(getConfigRevisionName(configName), destination);
  let [ yamlStatus, textOrNull ] = CONFIG_MGR.writeYAML(getConfigRevisionName(configName));
  if (yamlStatus == 0){
    const rc = xplatform.storeFileUTF8(destination, xplatform.AUTO_DETECT, textOrNull);
    //dont modify base config env if just component involved, upstream can do that.
    if (!rc && !componentId) {
      std.setenv('ZWE_CLI_PARAMETER_CONFIG', destination);
    } else if (rc) {
      if (!componentId) {
        console.log(`Error: Could not write .zowe-merged.yaml, ZWE_CLI_PARAMETER_CONFIG not modified!`);
      } else {
        console.log(`Error: Could not write .zowe-merged.yaml for ${componentId}`);
      }
      std.exit(1);
    }
    return {rc: rc, path: destination};
  }
  return {rc:yamlStatus};
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

function updateConfig(configName: string, updateObj: ZoweConfig, arrayMergeStrategy: number=1): number {
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

export function updateZoweConfig(updateObj: ZoweConfig, writeUpdate: boolean, arrayMergeStrategy: number=1): [number, any] {
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

function getMemberNameFromConfigPath(configPath: string): string|undefined {
  let indexParm = 0;
  let member = undefined;
  while (indexParm != -1) {
    indexParm = configPath.indexOf('PARMLIB(', indexParm);
    if (indexParm != -1) {
      const memberStart = configPath.indexOf('(', indexParm+8);
      if (memberStart == -1) {
        console.log(`Error: malformed PARMLIB syntax for ${configPath}. Must use syntax PARMLIB(dataset.name(member))`);
        return undefined;
      }
      const memberEnd = configPath.indexOf('))', memberStart+1);
      if (memberEnd == -1) {
        console.log(`Error: malformed PARMLIB syntax for ${configPath}. Must use syntax PARMLIB(dataset.name(member))`);
      }
      const thisMember = configPath.substring(memberStart+1, memberEnd);
      if (!member) {
        member = thisMember;
      } else if (thisMember != member) {
        console.log(`Error: configmgr does not yet support different member names for PARMLIB. You must use the same member names for all datasets mentioned`);
        return undefined;
      }
      //skip over )):
      indexParm = memberEnd+3; 
    }
  }
  return member;
}

function stripMemberName(configPath: string, memberName: string): string {
  //Turn PARMLIB(my.zowe(yaml)):PARMLIB(my.other.zowe(yaml))
  //Into PARMLIB(my.zowe):FILE(/some/path.yaml):PARMLIB(my.other.zowe)
  const replacer = new RegExp('\\('+memberName+'\\)\\)', 'gi');
  return configPath.replace(replacer, ")");
}
  
export function getConfig(configName: string, configPath: string, schemas: string): ZoweConfig|undefined {
  let configRevisionName = getConfigRevisionName(configName);
  if (Number.isInteger(CONFIG_REVISIONS[configName])) {
    //Already loaded
    return CONFIG_MGR.getConfigData(configRevisionName);
  }

  let memberName;
  if (configPath) {
    //In the form of PARMLIB(my.zowe(yaml)):PARMLIB(my.other.zowe(yaml))
    //Member names must be same for all PARMLIB mentioned.
    if (configPath.indexOf('PARMLIB(') != -1) {
      memberName = getMemberNameFromConfigPath(configPath);
      if (!memberName) {
        console.log(`Error: Cannot continue due to missing or mixed member names for PARMLIB entries in ${configPath}`);
        std.exit(1);
      }
      configPath = stripMemberName(configPath, memberName);
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

    if (memberName) {
      if ((status = CONFIG_MGR.setParmlibMemberName(configRevisionName, memberName))) {
        console.log(`Error: Could not set parmlib member name for ${memberName}, status=${status}`);
        std.exit(1);
      }
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
  return undefined;
}


function getSchemasForComponentConfig(manifest: ComponentManifest, componentDir: string): string|undefined {
  let baseSchemas = getZoweBaseSchemas();
  if (manifest.schemas?.configs) {
    if (Array.isArray(manifest.schemas.configs)) {
      return manifest.schemas.configs.map(path=>componentDir+'/'+path).join(':')+":"+baseSchemas;
    } else {
      return componentDir+'/'+manifest.schemas.configs+":"+baseSchemas;
    }
  }
  return undefined;
}

function getConfigListForComponent(manifest: ComponentManifest, configPath: string, componentDir: string): string {
  if (configPath.startsWith('/')) { //likely input is merged yaml
    configPath=`FILE(${configPath})`; 
  }

  //TODO revisit when zowe itself gets defaults.yaml, as not sure if components should override zowe or not.
  //  For now, component defaults get overridden by everything else by putting them last.
  if (manifest.configs?.defaults) {
    if (Array.isArray(manifest.configs.defaults)) {
      configPath+=':'+manifest.configs.defaults.map((entry)=> `FILE(${componentDir}/${entry})`).join(':');
    } else {
      configPath+=`:FILE(${componentDir}/${manifest.configs.defaults})`;
    }
  }
  return configPath;
}

export function getComponentConfig(componentId: string, manifest: ComponentManifest, componentDir: string, configPath: string): {path: string, name: string, contents: ZoweConfig}|undefined {
  configPath = getConfigListForComponent(manifest, configPath, componentDir);
  let schemas = getSchemasForComponentConfig(manifest, componentDir);

  
  const validationMode = ZOWE_CONFIG.zowe.configmgr?.validation ? ZOWE_CONFIG.zowe.configmgr.validation : 'COMPONENT-COMPAT';
  if (!schemas && validationMode != 'COMPONENT-COMPAT') { //can be undefined if not stated in manifest.yaml
    console.log(`Error: Component ${componentId} is missing property manifest property schemas.configs, validation will fail`);
    return undefined;
  } else if (!schemas) {
    console.log(`Error: DEPRECATED: Component ${componentId} does not have a schema file defined in manifest property schemas.configs! Skipping config validation for this component. This may fail in future versions of Zowe. Updating the component is recommended.`);
    schemas = getZoweBaseSchemas();
  }

  const configName = `zowe.yaml-${componentId}`;
  const contents = getConfig(configName, configPath, schemas);
  writeMergedConfig(contents, componentId);
  return {path: configPath, name: configName, contents: contents};
}

export function getZoweConfig(): ZoweConfig {
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
export function getZoweConfigEnv(haInstance: string, config:ZoweConfig=getZoweConfig()): any {
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
    let list = getDiscoveryServiceUrl(config);
    envs['ZWE_DISCOVERY_SERVICES_LIST'] = list.join(',');
  }

  envs['ZWE_haInstance_id'] = haInstance;
  
  return envs;
}
