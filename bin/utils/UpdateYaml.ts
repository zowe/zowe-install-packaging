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

// scriptArgs is a quickJS global equivalent to node's process.argv
const pgmArgs = scriptArgs.slice(3);

if (!scriptArgs[0].includes('configmgr') || !scriptArgs[1].includes('-script') || pgmArgs.length < 3) { 
  common.printErrorAndExit('UpdateYaml script was not invoked with the correct number of arguments. Usage: ./configmgr -script <this_script> <file> <key> <value>')
}

const file = pgmArgs[0];
const key = pgmArgs[1];
let newValue = pgmArgs[2]; // always comes wrapped in quotes

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
let rc = 0;
rc = jsonlib.updateZoweYaml(file, key, newValue);
if (rc != 0) {
  // could be schema issue, check if newValue is a number
  if (/^\d+$/.test(newValue)) {
    common.printTrace(`Initial update failed, trying again with this value as a number: ${newValue}`)
    rc = jsonlib.updateZoweYaml(file, key, parseInt(newValue));
  }
}
std.exit(rc);
