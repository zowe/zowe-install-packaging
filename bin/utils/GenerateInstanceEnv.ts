/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

/** 
*   This provides a way for `libs/config.sh` to generate instance env's from zowe yaml using configmgr,
*    rather than calling a nodejs script.
*/
import * as common from '../libs/common';
import * as std from 'cm_std';
import * as sys from '../libs/sys';
import * as config from '../libs/config';

// scriptArgs is a quickJS global equivalent to node's process.argv
const pgmArgs = scriptArgs.slice(3);
if (!scriptArgs[0].includes('configmgr') || !scriptArgs[1].includes('-script') || pgmArgs.length < 1) {
  common.printErrorAndExit('UpdateYaml script was not invoked with the correct number of arguments. Usage: ./configmgr -script <this_script> <haInstance> <tmp_dir>');
}
let haInstance = pgmArgs[0];
const tmpDir = pgmArgs[1];
if (haInstance == null || haInstance.trim().length == 0){
  haInstance = sys.getSysname();
}
if (tmpDir != null && tmpDir.trim().length > 0) {
  std.setenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR', tmpDir);
}
config.generateInstanceEnvFromYamlConfig(haInstance);
std.exit(0);
