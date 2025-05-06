/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

/** 
*   This provides a way for `libs/config.sh` to convert zowe.yaml files to instance-envs using configmgr.
*   This part of config.sh is used by the migrate for kubernetes command group. In the future, if we convert that command
*    from shell to configmgr ts, the core logic from this class can be moved somewhere in libs/.
*/
import * as jsonlib from '../libs/json';
import * as common from '../libs/common';
import * as std from 'cm_std';
import * as sys from '../libs/sys';
import * as fakejq from '../libs/'
import { CONFIG_MGR } from '../libs/configmgr';

const CONFIG_ACTIONS = {
  convert: 'convert',
  generateEnv: 'env'
}

const pgmArgs = scriptArgs.slice(3);

if (!scriptArgs[0].includes('configmgr') || !scriptArgs[1].includes('-script') || pgmArgs.length < 1) { 
  common.printErrorAndExit('ConfigConverter script was not invoked through configManager, please use "configmgr -script <this_script> <script_args>"');
}

// parse cmd line options
const cfgAction = pgmArgs[0];
let pgmOptions = pgmArgs.slice(1);
let haInstance;
let workspaceDir;
let verbose = false;
let configFile;

while (pgmOptions.length > 0){
  let advanceCt = 1;
  switch (pgmOptions[0]) {
    case '--wd':
      if (pgmOptions.length < 2) {
        common.printErrorAndExit('--wd option missing corresponding value');
      }
      workspaceDir = pgmOptions[1];
      advanceCt = 2;
      break;
    case '--ha':
      if (pgmOptions.length < 2) {
        common.printErrorAndExit('--ha option missing corresponding value');
      }
      haInstance = pgmOptions[1];
      advanceCt = 2;      
      break;
    case '--verbose':
      verbose = true;
      break;
    default:
      if (configFile) {
        common.printErrorAndExit(`this script only supports one parameter, received: ${configFile} and ${pgmOptions[0]}`)
      }
      configFile = pgmOptions[0];
      break;
  }
  pgmOptions = pgmOptions.slice(advanceCt);
}

if (configFile == null) {
  common.printErrorAndExit('You must pass a zowe configuration file to this script.');
}
if (haInstance == null) {
  haInstance = sys.getSysname();
}
/*
if (cfgAction === CONFIG_ACTIONS.convert) {
    convertConfigs()
} else if (cfgAction === CONFIG_ACTIONS.generateEnv) {

} else {
  common.printErrorAndExit(`Unrecognized config action: ${cfgAction}. Please use one of "${CONFIG_ACTIONS.convert}" or "${CONFIG_ACTIONS.generateEnv}"`);
}





// consider all overrides based on HA-Instance-ID, save the converted configs
const convertConfigs = (configObj, haInstance, workspaceDir = null) => {
  workspaceDir = workspaceDir ? workspaceDir : std.getenv.WORKSPACE_DIR;
  if (!workspaceDir) {
    throw new Error('Environment WORKSPACE_DIR is required');
  }

  const configObjCopy = fakejq.merge({}, configObj);

  // find components
  const components = fs.readdirSync(workspaceDir).filter(file => {
    return fs.statSync(path.resolve(workspaceDir, file)).isDirectory();
  });
  if (std.getenv[VERBOSE_ENV]) {
    console.log(`- found ${components.length} components\n`);
  }
  // apply components configs as default values
  components.forEach(component => {
    if (!fs.existsSync(path.resolve(workspaceDir, component, '.manifest.json'))) {
      if (std.getenv[VERBOSE_ENV]) {
        console.log(`  - component ${component} doesn't have manifest\n`);
      }
      return;
    }
    if (std.getenv[VERBOSE_ENV]) {
      console.log(`  - read ${component} manifest\n`);
    }
    const manifest = simpleReadJson(path.resolve(workspaceDir, component, '.manifest.json'));
    if (manifest.configs) {
      if (!configObjCopy.components) {
        configObjCopy.components = {};
      }
      configObjCopy.components[component] = _.defaultsDeep(configObjCopy.components[component] || {}, manifest.configs);
    }
  });

  // write workspace/.zowe.json
  if (std.getenv[VERBOSE_ENV]) {
    console.log(`- write <workspace-dir>/.zowe.json\n`);
  }
  // FIXME: will we have issue of competing write with multiple ha instance starting at same time?
  writeJson(configObjCopy, path.resolve(workspaceDir, '.zowe.json'));

  // prepare haInstance.id, haInstance.hostname and haInstance.ip
  if (std.getenv[VERBOSE_ENV]) {
    console.log(`- process HA instance "${haInstance}"\n`);
  }
  const haCopy = merge({}, configObjCopy);
  const haCopyMerged = merge(haCopy, _.omit(configObjCopy.haInstances && configObjCopy.haInstances[haInstance] || {}, ['id', 'hostname', 'ip']));
  _.set(haCopyMerged, 'haInstance.id', haInstance);
  _.set(haCopyMerged, 'haInstance.hostname', 
    (
      (configObjCopy.haInstances && configObjCopy.haInstances[haInstance] && configObjCopy.haInstances[haInstance].hostname) || 
      (configObjCopy.zowe && configObjCopy.zowe.externalDomains && configObjCopy.zowe.externalDomains[0]) ||
      ''
    )
  );
  _.set(haCopyMerged, 'haInstance.ip', 
    (
      (configObjCopy.haInstances && configObjCopy.haInstances[haInstance] && configObjCopy.haInstances[haInstance].ip) || 
      (configObjCopy.zowe && configObjCopy.zowe.environments && configObjCopy.zowe.environments['ZOWE_IP_ADDRESS']) ||
      ''
    )
  );
  writeJson(haCopyMerged, path.resolve(workspaceDir, `.zowe-${haInstance}.json`));

  // prepare component configs and write component configurations
  // IMPORTANT: these configs will be used to generate component runtime environment
  components.forEach(component => {
    if (haCopyMerged.components && haCopyMerged.components[component]) {
      const componentCopy = merge({}, haCopyMerged);
      _.set(componentCopy, 'configs', haCopyMerged.components[component]);

      if (std.getenv[VERBOSE_ENV]) {
        console.log(`    - write <workspace-dir>/${component}/.configs-${haInstance}.json\n`);
      }
      writeJson(componentCopy, path.resolve(workspaceDir, component, `.configs-${haInstance}.json`));
      // if (std.getenv[VERBOSE_ENV]) {
      //   console.log(`    - write <workspace-dir>/${component}/.configs-${haInstance}.yaml\n`);
      // }
      // writeYaml(componentCopy, path.resolve(workspaceDir, component, `.configs-${haInstance}.yaml`));
    }
  });
};
*/
