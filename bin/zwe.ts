/*
// This program and the accompanying materials are made available
// under the terms of the Eclipse Public License v2.0 which
// accompanies this distribution, and is available at
// https://www.eclipse.org/legal/epl-v20.html
//
// SPDX-License-Identifier: EPL-2.0
//
// Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as zwecli from './libs/zwecli';
import * as common from './libs/common';

//arguments minus command name
let ZWE_TS_CLI_ARGUMENTS = (globalThis.scriptArgs as any).slice(1);

let ZWE_zowe_runtimeDirectory = std.getenv('ZWE_zowe_runtimeDirectory');


let ZWE_TS_COMMAND_WORDS = [];
let ZWE_TS_PARAMETERS = [];
let parametersArea = false;
for (let i = 0; i < ZWE_TS_CLI_ARGUMENTS.length; i++) {
  let element = ZWE_TS_CLI_ARGUMENTS[i];
  if (element.startsWith('-')) { //signifies a parameter, and the start of the parameters area
    parametersArea = true;
    ZWE_TS_PARAMETERS.push(element.trim());
  } else if (!parametersArea) { //comes before parameters
    ZWE_TS_COMMAND_WORDS.push(element.trim());
  } else { //a value of a parameter
    ZWE_TS_PARAMETERS.push(element.trim());
  }
}

let ZWE_TS_COMMAND_PATH = ZWE_zowe_runtimeDirectory + '/bin/commands';
if (ZWE_TS_COMMAND_WORDS.length > 0) { ZWE_TS_COMMAND_PATH+= '/' + ZWE_TS_COMMAND_WORDS.join('/');}

const parmDefs: {[key: string]: zwecli.ZweParameter} = zwecli.zwecli_load_parameters_definition(ZWE_TS_COMMAND_WORDS);
for (let i = 0; i < ZWE_TS_PARAMETERS.length; i++) {
  let rawParm = ZWE_TS_PARAMETERS[i];
  let parm = rawParm.startsWith('--') ? rawParm.substring(2) : rawParm.substring(1);
  let definition = parmDefs[parm];
  
  if (!definition) {
    common.printErrorAndExit(`Error ZWEL0102E: Invalid parameter ${rawParm}`, undefined, 102);
  }

  if (definition.type == zwecli.ZweParameterTypes.boolean) {
    definition.value = true;
    std.setenv(zwecli.zwecli_get_parameter_env_name(definition), 'true');
  } else if (definition.type == zwecli.ZweParameterTypes.string) {
    ++i;
    let rawValue = ZWE_TS_PARAMETERS[i];
    definition.value = rawValue;
    std.setenv(zwecli.zwecli_get_parameter_env_name(definition), rawValue);
  } else {
    common.printErrorAndExit(`Error ZWEL0103E: Invalid type of parameter ${rawParm}`, undefined, 103);
  }
}

// process
// TODO: separate verbose level by terminal output and log file
zwecli.zwecli_process_loglevel(parmDefs);
// if it's in help mode, the script will exit with code 100
if (parmDefs.help) {
  zwecli.zwecli_process_help(ZWE_TS_COMMAND_WORDS);
}
// prepare log file if directory specified
// TODO: logDirectory could be defined in zowe.yaml different sections
zwecli.zwecli_process_logfile(parmDefs, ZWE_TS_COMMAND_WORDS);

// validate parameter before execute command
zwecli.zwecli_validate_parameters(parmDefs);
// handle command
await zwecli.zwecli_process_command();
