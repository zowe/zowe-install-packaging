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
import * as common from './common';
import * as stringlib from './string';
import * as shell from './shell';
import * as fakejq from './fakejq';
import * as config from './config';
import * as zosfs from './zos-fs';

// Read JSON configuration from shell script
//
// Note: this is not a reliable way to read JSON file. The JSON file must be
//       properly formatted, each key/value pair takes one line.
//
// FIXME: we should have a language neutral JSON reading tool, not using shell script.
//
// @param string   JSON file name
// @param string   parent key to read after
// @param string   which key to read
// @param string   if this variable is required. If this is true and we cannot
//                 find the value of the key, an error will be displayed.
export function shellReadJsonConfig(jsonFile: string, parentKey: string, key: string, required: boolean): any {
  let val=shell.execOutSync('sh', '-c', `cat "${jsonFile}" | awk "/\"${parentKey}\":/{x=NR+200}(NR<=x){print}" | grep "\"${key}\":" | head -n 1 | awk -F: '{print $2;}' | tr -d '[[:space:]]' | sed -e 's/,$//' | sed -e 's/^"//' -e 's/"$//'`);
  if (!val.out) {
    if (required == true) {
      common.printErrorAndExit(`Error ZWEL0131E: Cannot find key ${parentKey}.${key} defined in file ${jsonFile}.`, undefined, 131);
    }
  } else {
    return val.out;
  }
}


// Read YAML configuration from shell script
//
// Note: this is not a reliable way to read YAML file, but we need this to find
//       out ROOT_DIR to execute further functions.
//
// FIXME: we should have a language neutral YAML reading tool, not using shell script.
//
// @param string   YAML file name
// @param string   parent key to read after
// @param string   which key to read
// @param string   if this variable is required. If this is true and we cannot
//                 find the value of the key, an error will be displayed.
export function shellReadYamlConfig(yamlFile: string, parentKey: string, key: string, required: boolean): any {
  const val=shell.execOutSync('sh', '-c', `cat "${yamlFile}" | awk "/^ *${parentKey}:/{x=NR+2000;next}(NR<=x){print}" | grep -e "^ \+${key}:" | head -n 1 | awk -F: '{print $2;}' | tr -d '[[:space:]]' | sed -e 's/^"//' -e 's/"$//'`);
  if (!val.out) {
    if (required==true) {
      common.printErrorAndExit(`Error ZWEL0131E: Cannot find key ${parentKey}.${key} defined in file ${yamlFile}.`, undefined, 131);
    } else {
      return val;
    }
  }
}

export function readJsonString(input: string, key: string): any {
  return fakejq.jqget(JSON.parse(input), key);
}

/**
 * Deletes the YAML key in the zowe.yaml file passed by the caller. Always overwrites on-disk.
 * 
 * Example: `deleteZoweYaml('/path/to/zowe.yaml', 'components.zss.enabled');
 * 
 * @param file 
 * @param key 
 * @returns 
 */
export function deleteZoweYaml(file: string, key: string): number {
  common.printMessage(`- delete zowe config ${file}, key: ${key}`);
  const deleteResult = config.deleteFromZoweCfgFile(file, key);
  return deleteResult[0];
}

/**
 * Updates the YAML key in the zowe.yaml passed by the caller with val. Always overwrites on-disk.
 * 
 * Example: `updateZoweYaml('/path/to/zowe.yaml', 'components.zss.enabled', true);
 * 
 * @param file 
 * @param key 
 * @param val 
 * @returns 
 */
export function updateZoweYaml(file: string, key: string, val: any): number {
  common.printMessage(`- update zowe config ${file}, key: "${key}" with value: ${val}`);
  let [ success, updateObj ] = fakejq.jqset({}, key, val);
  if (success) {
    common.printMessage(`  * Success`);
    const updateResult = config.updateZoweCfgFile(file, updateObj, 1);
    return updateResult[0];
  } else {
    common.printError(`  * Error`); 
    return -1;
  }
}

/**
 * Updates the in-use zowe.yaml provided via ZWE_CLI_PARAMETER_CONFIG with the contents of `updateObj`
 * 
 * @param updateObj 
 */
export function updateZoweYamlFromObj(updateObj: any) {
  common.printMessage(`- update zowe config ${std.getenv('ZWE_CLI_PARAMETER_CONFIG')} with obj=${JSON.stringify(updateObj, null, 2)}`);
  config.updateZoweConfig(updateObj, true, 1); //TODO externalize array merge strategy = 1
}
