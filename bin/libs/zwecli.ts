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
import * as xplatform from 'xplatform';
import * as common from './common';
import * as logging from './logging';
import * as strftime from './strftime';
import * as stringlib from './string';
import * as fs from './fs';


import * as zwe_components_disable from '../commands/components/disable/cli.js';
import * as zwe_components_enable from '../commands/components/enable/cli.js';
import * as zwe_components_install from '../commands/components/install/cli.js';
import * as zwe_components_search from '../commands/components/search/cli.js';
import * as zwe_components_uninstall from '../commands/components/uninstall/cli.js';
import * as zwe_components_upgrade from '../commands/components/upgrade/cli.js';

import * as zwe_config_get from '../commands/config/get/cli.js';
import * as zwe_config_validate from '../commands/config/validate/cli.js';

import * as zwe_diagnose from '../commands/diagnose/cli.js';
import * as zwe_stop from '../commands/stop/cli.js';
import * as zwe_start from '../commands/start/cli.js';

import * as zwe_support from '../commands/support/cli.js';
import * as zwe_support_verify_fingerprints from '../commands/support/verify-fingerprints/cli.js';

// Global variables
std.setenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS','INFO');

function zwecli_append_parameters_definition(command_path: string, parameters: string[]): string[] {
  if (fs.directoryExists(command_path)) {
    let parameterPath = command_path+'/.parameters'
    if (fs.fileExists(parameterPath)) {
      const contents:string[] = xplatform.loadFileUTF8(parameterPath,xplatform.AUTO_DETECT).split('\n').filter(line => line.indexOf('|') != -1);
      parameters = parameters.concat(contents);
    }
  } else {
    let commands = command_path.substring((std.getenv('ZWE_zowe_runtimeDirectory') +'/bin/commands').length);
    if (commands.length > 0) {
      commands = commands.replace(/\//g, ' ');
      common.printError(`Error ZWEL0104E: Invalid command "${commands}"`);
      common.printErrorAndExit("Try --help to get information about what commands are available.", undefined, 104);
    }
  }
  return parameters;
}

function zwecli_append_exclusive_parameters_definition(command_path: string, parameters: string[]): string[] {
  if (fs.directoryExists(command_path)) {
    let parameterPath = command_path+'/.exclusive-parameters'
    if (fs.fileExists(parameterPath)) {
      const contents = xplatform.loadFileUTF8(parameterPath,xplatform.AUTO_DETECT).split('\n').filter(line => line.indexOf('|') != -1);
      parameters = parameters.concat(contents);
    }
  } else {
    let commands = command_path.substring((std.getenv('ZWE_zowe_runtimeDirectory') +'/bin/commands').length);
    if (commands.length > 0) {
      commands = commands.replace(/\//g, ' ');
      common.printError(`Error ZWEL0104E: Invalid command "${commands}"`);
      common.printErrorAndExit("Try --help to get information about what commands are available.", undefined, 104);
    }
  }
  return parameters;
}

export function zwecli_load_parameters_definition(commands: string[]): {[key: string]: ZweParameter} {
  let currentCommandPath = std.getenv('ZWE_zowe_runtimeDirectory') +'/bin/commands';
  let parameterStrings: string[] = [];
  //global first
  parameterStrings = zwecli_append_parameters_definition(currentCommandPath, parameterStrings);

  commands.forEach((command)=> {    
    currentCommandPath+='/'+command;
    parameterStrings = zwecli_append_parameters_definition(currentCommandPath, parameterStrings);
  });
  parameterStrings = zwecli_append_exclusive_parameters_definition(currentCommandPath, parameterStrings);
  return zwecli_generate_parameters_map(parameterStrings);
}

function zwecli_generate_parameters_map(parameters: string[]): {[key: string]: ZweParameter} {
  let map: {[key: string]: ZweParameter} = {};
  parameters.forEach((parameter)=> {
    let parts = parameter.split('|');
    let zweParameter: ZweParameter = {
      longNames: parts[0].split(','),
      shortName: parts[1].length > 0 ? parts[1] : undefined,
      type: parts[2] == 'string' ? ZweParameterTypes.string : ZweParameterTypes.boolean,
      required: parts[3] == 'required',
      defaultValue: parts[4].length > 0 ? parts[4] : undefined,
      description: parts[7]
    };
    zweParameter.value = zweParameter.defaultValue;
    map[zweParameter.shortName] = zweParameter;
    zweParameter.longNames.forEach((name)=> {
      map[name] = zweParameter;
    });
  });
  return map;
}

export function zwecli_get_parameter_env_name(parameter: ZweParameter): string {
  return 'ZWE_CLI_PARAMETER_'+stringlib.sanitizeAlphanum(parameter.longNames[0].toUpperCase());
}

export function zwecli_get_parameter_value(longName: string, parameters: {[key: string]: ZweParameter}): string|number|boolean|undefined {
  let parameter = parameters[longName];
  if (parameter) {
    return parameter.value;
  }
  return undefined;
}

//old code said that types 'b' and 'bool', 's' and 'str' could exist, but never did.
export enum ZweParameterTypes {
  string,
  boolean
}

export type ZweParameter = {
  longNames: string[]
  shortName?: string
  type: ZweParameterTypes
  required: boolean
  defaultValue?: string|number|boolean;
  value?: string|number|boolean;
  //unk1
  //unk2
  description: string;
};

export function zwecli_process_loglevel(parameters: {[key: string]: ZweParameter}) {
  let debug = zwecli_get_parameter_value('debug', parameters);
  if (debug == true) {
    std.setenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS', 'DEBUG');
  }
  let trace = zwecli_get_parameter_value('trace', parameters);
  if (trace == true) {
    std.setenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS', 'TRACE');
  }
}

export function zwecli_process_logfile(parameters: {[key: string]: ZweParameter}, commandList?: string[]) {
  let logDir = std.getenv('ZWE_CLI_PARAMETER_LOG_DIR');
  if (logDir) {
    let log_prefix='zwe';
    if (commandList) {
      log_prefix = `zwe-${commandList.join('-')}`;
    }
    logging.prepareLogFile(std.getenv("ZWE_CLI_PARAMETER_LOG_DIR"), log_prefix);

    // write initial information
    common.printMessage(`Zowe server command: zwe ${commandList.join(' ')}`, ["log"]);
    common.printMessage(`- timestamp: ${strftime.strftime("%Y-%m-%d %H:%M:%S")}`, ["log"]);
    common.printMessage("- parameters:", ["log"]);

    let envVars = std.getenviron();
    let parmKeys = Object.keys(envVars).filter((key)=> key.startsWith('ZWE_CLI_PARAMETER_'));
    parmKeys.forEach((key)=> {
      common.printMessage(`  * ${key}: ${envVars[key]}`, ["log"]);
    });
    common.printMessage("", ["log"]);
  }
}

function zwecli_display_parameters_help(filename: string) {
  const parameters = xplatform.loadFileUTF8(filename,xplatform.AUTO_DETECT).split('\n').filter(line => line.indexOf('|') != -1);
  parameters.forEach((parameter)=> {
    let parts = parameter.split('|');
    let zweParameter: ZweParameter = {
      longNames: parts[0].split(','),
      shortName: parts[1].length > 0 ? parts[1] : undefined,
      type: parts[2] == 'string' ? ZweParameterTypes.string : ZweParameterTypes.boolean,
      required: parts[3] == 'required',
      description: parts[7]
    };
    let line = '    ';
    line+= zweParameter.longNames.map(name=> '--'+name).join('|');
    if (zweParameter.shortName) {
      line+= '|-' + zweParameter.shortName;
    }
    if (zweParameter.type == ZweParameterTypes.string) {
      line+= ' string';
    }
    if (zweParameter.required) {
      line+= ' (required)';
    } else {
      line+= ' (optional)';
    }

    console.log(line);
    console.log(stringlib.paddingLeft(zweParameter.description, "        "));
    console.log();
  });
}

export function zwecli_process_help(ZWE_CLI_COMMANDS_LIST: string[]) {
  let commandString = ZWE_CLI_COMMANDS_LIST.join(' ');
  console.log(`zwe ${commandString}`);
  console.log();
  let command_path_full = std.getenv('ZWE_zowe_runtimeDirectory') +'/bin/commands/'+ZWE_CLI_COMMANDS_LIST.join('/');

  // Display synopsis (command format)
  //    zwe  [sub-command [sub-command]...] [parameter [parameter]...]
  let subdirectories: string[] = fs.getSubdirectories(command_path_full).filter(name => !name.startsWith('.'));
  let sub_command_level='';
  if (subdirectories && subdirectories.length > 0) {
    sub_command_level="[sub-command]"
    for (let i = 0; i < subdirectories.length; i++) {
      let subsubdirectories = fs.getSubdirectories(command_path_full+'/'+subdirectories[i]);
      if (subsubdirectories && subsubdirectories.length > 0) {
        sub_command_level="[sub-command [sub-command]...]"
        break;
      }
    }
  }

  let parameter_level = "[parameter]...";
  if (fs.fileExists(command_path_full+'/.parameters') || fs.fileExists(command_path_full+'/.exclusive-parameters') || (sub_command_level.length > 0)) {
    parameter_level="[parameter [parameter]...]"
  }

  console.log("------------------");
  console.log("Synopsis");

  if (sub_command_level.length > 0) {
    console.log(`    zwe ${commandString} ${sub_command_level} ${parameter_level}`)
  } else {
    console.log(`    zwe ${commandString} ${parameter_level}`);
  }
  console.log();

  // display description message if exists
  if (fs.fileExists(command_path_full+'/.help')) {
    console.log("------------------");
    console.log("Description");

    const contents = xplatform.loadFileUTF8(command_path_full+'/.help',xplatform.AUTO_DETECT);
    console.log(stringlib.paddingLeft(contents, "    "));
    console.log();
  }

  // display global parameters
  let globalParametersFile = std.getenv('ZWE_zowe_runtimeDirectory') +'/bin/commands/.parameters';
  if (fs.fileExists(globalParametersFile)) {
    console.log("------------------");
    console.log("Global parameters");
    
    zwecli_display_parameters_help(globalParametersFile);
  }

  // display command parameters
  let command_tree='';
  let command_path=std.getenv('ZWE_zowe_runtimeDirectory') +'/bin/commands';
  ZWE_CLI_COMMANDS_LIST.forEach((command)=> {
    command_tree+=' '+command;
    command_path+='/'+command;
    if (fs.fileExists(command_path+'/.experimental')) {
      console.log(`WARNING: command "${command_tree.trim()}" is for experimental purpose.`);
      console.log();
    }
    let parametersExists = fs.fileExists(command_path+'/.parameters');
    let exclusiveExists = fs.fileExists(command_path+'/.exclusive-parameters');
    if (parametersExists || exclusiveExists) {      
      console.log("------------------");
      console.log(`Parameters for command "${command_tree.trim()}"`);
      if (parametersExists) {
        zwecli_display_parameters_help(command_path+'/.parameters');
      }
      if (exclusiveExists) {
        zwecli_display_parameters_help(command_path+'/.exclusive-parameters');
      }
    }
  });
  
  // find sub-commands
  subdirectories = fs.getSubdirectories(command_path_full).filter((subdirectory)=> !subdirectory.startsWith('.'));
  if (subdirectories && subdirectories.length > 0) {
    console.log("------------------");
    console.log("Available sub-command(s)");
    subdirectories.forEach((subdirectory)=> {
      console.log(`    - ${subdirectory}`)
    });
    console.log();
  }

  // display example(s)
  if (fs.fileExists(command_path_full+'/.examples')) {
    console.log("------------------");
    console.log("Example(s)");
    const contents = xplatform.loadFileUTF8(command_path_full+'/.examples',xplatform.AUTO_DETECT);
    console.log(stringlib.paddingLeft(contents, "    "));
    console.log();
  }
  
  std.exit(100);
}

export function zwecli_validate_parameters(parameters: {[key: string]: ZweParameter}) {
  let required_params=[];

  let keys = Object.keys(parameters);
  keys.forEach((key)=> {
    let parameter = parameters[key];
    let envName = zwecli_get_parameter_env_name(parameter);
    if (!required_params.includes(envName)) {
      if (parameter.required) {
        required_params.push(envName);
        let value = std.getenv(envName);
        if (value == undefined || value.length == 0) {
          common.printError(`Error ZWEL0106E: ${parameter.longNames[0]} parameter is required`);
          common.printErrorAndExit("Try --help to get information about how to use this command.", undefined, 106);
        }
      }
    }
  });
}

export function zwecli_process_command(commands?: string[]) {
  if (commands) {
    let commandJoin = commands.join(' ');
    if (commandJoin == 'components disable') {
      zwe_components_disable.execute();
    } else if (commandJoin == 'components enable') {
      zwe_components_enable.execute();
    } else if (commandJoin == 'components install') {
      zwe_components_install.execute();
    } else if (commandJoin == 'components search') {
      zwe_components_search.execute();
    } else if (commandJoin == 'components uninstall') {
      zwe_components_uninstall.execute();
    } else if (commandJoin == 'components upgrade') {
      zwe_components_upgrade.execute();
    } else if (commandJoin == 'config get') {
      zwe_config_get.execute();
    } else if (commandJoin == 'config validate') {
      zwe_config_validate.execute();
    } else if (commandJoin == 'diagnose') {
      zwe_diagnose.execute();
    } else if (commandJoin == 'stop') {
      zwe_stop.execute();
    } else if (commandJoin == 'start') {
      zwe_start.execute();
    } else if (commandJoin == 'support') {
      zwe_support.execute();
    } else if (commandJoin == 'support verify fingerprints') {
      zwe_support_verify_fingerprints.execute();
    } else {
      common.printError(`Error ZWEL0107E: No handler defined for command "${commandJoin}".`);
    }
  } else {
    common.printErrorAndExit("Try --help to get information about how to use this command.", ["console"], 107);
  }
}
