/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

/** 
*   This provides a way for `libs/json.sh` to update yaml via configmgr,
*   rather than calling a nodejs script.
*/
import * as jsonlib from '../libs/json';
import * as common from '../libs/common';
import * as std from 'cm_std';

const MOD_TYPES = {
  delete: 'delete',
  update: 'update'
}

// scriptArgs is a quickJS global equivalent to node's process.argv
const pgmArgs = scriptArgs.slice(3);

if (!scriptArgs[0].includes('configmgr') || !scriptArgs[1].includes('-script') || pgmArgs.length < 3) { 
  common.printErrorAndExit('UpdateYaml script was not invoked with the correct number of arguments. Usage: ./configmgr -script <this_script> update <file> <key> <value> OR ./configmgr -script <this_script> delete <file> <key>');
}

const modType = pgmArgs[0];
const file = pgmArgs[1];
const key = pgmArgs[2];
let rc = 0;

if (modType == MOD_TYPES.update) {
  // the final type of newValue changes based on parsing logic, and dynamic typing is used to distinguish "true" and true in the updated YAML.
  let newValue: any = pgmArgs[3]; // always comes wrapped in quotes.

  // convert string of boolean to real boolean
  if (newValue === 'true') {
    newValue = true;
  } else if (newValue === 'false') {
    newValue = false;
  } else if (newValue === '' || newValue === '""' || newValue === '\'\'' || newValue === '\'""\'' || newValue === '"\'\'"') {
    // sometimes ansible may send empty string as '""'
    newValue = '""';
  } 
  
  common.printTrace(`Updating: ${file}, ${key}, ${newValue}`)
  rc = jsonlib.updateZoweYaml(file, key, newValue);
  if (rc != 0) {
    // could be schema issue, check if newValue is a number
    if (/^\d+$/.test(newValue)) {
      common.printTrace(`Initial update failed, trying again with this value as a number: ${newValue}`)
      rc = jsonlib.updateZoweYaml(file, key, parseInt(newValue));
    }
  }
} else if (modType == MOD_TYPES.delete) {
  common.printTrace(`Deleting: ${file}, ${key}`);
  rc = jsonlib.deleteZoweYaml(file, key);
}

std.exit(rc);
