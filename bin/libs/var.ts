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
import * as fs from './fs';
import * as shell from './shell';
import * as common from './common';
import * as stringlib from './string';

// internal errors counter for validations
std.setenv('ZWE_PRIVATE_ERRORS_FOUND', '0');

// Check if a shell function is defined
export function functionExists(fn: string): boolean {
  let lcAll=std.getenv('LC_ALL');
  std.setenv('LC_ALL', 'C');
  let shellReturn = shell.execOutSync('type', fn);// 2>&1 | grep 'function')
  std.setenv('LC_ALL', lcAll);
  
  if (shellReturn.out) {
    return shellReturn.out.split('\n')[0].endsWith('function');
  }
  return false;
}


// if a string has any env variables, replace them with values
export function parseStringVars(key: string): string|undefined {
  return std.getenv(key);
}

// return value of the variable
export function getVarValue(key: string): string {
  return `\$\{${std.getenv(key)}`;
}

// get all environment variable exports line by line
const exportFilter=/^export (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD=|PS1=|ENV=|LS_COLORS=|_=)/
  const declareFilter=/^declare -x (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD|PS1=|ENV=|LS_COLORS=|_=)/

const keyFilter=/^(run_zowe_start_component_id|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file|key|line|service|logger|level|expected_log_level_val|expected_log_level_var|display_log|message|utils_dir|print_formatted_function_available|LINENO|ENV|opt|OPTARG|OPTIND|LOGNAME|USER|SSH_|SHELL|PWD|OLDPWD|PS1|ENV|LS_COLORS|_)$/

export function getEnvironmentExports(): string {
  let envvars = std.getenviron();
  let keys = Object.keys(envvars);
  let exports=[];
  keys.forEach((key: string)=> {
    if (keyFilter.test(key)) {
      exports.push(`export ${key}=${envvars[key]}`);
    }
  });
  return exports.join('\n');
}

// get all environment variable exports line by line
export function getEnvironments(): string {
  let envvars = std.getenviron();
  let keys = Object.keys(envvars);
  let exports=[];
  keys.forEach((key: string)=> {
    if (keyFilter.test(key)) {
      exports.push(`${key}=${envvars[key]}`);
    }
  });
  return exports.join('\n');
}

// Shell sourcing an environment env file
//
// All variables defined in env file will be exported.
export function sourceEnv(envFile: string): boolean {
  //TODO i hope encoding is correct here
  let fileContents = std.loadFile(envFile);
  if (fileContents === null) {
    common.printError(`Error loading file ${envFile}`);
    return false;
  }

  let fileLines = fileContents.split('\n');
  let index;
  fileLines.forEach((line: string)=> {
    if ((index = line.indexOf('=')) != -1) {
      std.setenv(line.substring(0,index), line.substring(index+1));
      common.printTrace(`Set env var ${line.substring(0, index)} to ${std.getenv(line.substring(0,index)}`);
    }
  });
}

// Takes in a single parameter - the name of the variable
export function isVariableSet(variableName: string, message?: string): boolean {
  if (!message) {
    message=`${variableName} is not defined or empty.`
  }
  const value = std.getenv(variableName);
  if (value === undefined) {
    common.printError(message);
    return false;
  }
  return true;
}

// Takes in a list of space separated names of the variables
export function areVariablesSet(variables: string[]): number {
  let invalid=0
  
  variables.forEach((variable: string) => {
    if (!isVariableSet(variable)) {
      invalid++;
    }
  });
  
  return invalid;
}

export function validateThis(cmd: string, origin: string): number {
  common.printFormattedTrace("ZWELS", origin, `Validate: ${cmd}`);
  let shellReturn = shell.execOutErrSync('sh', `eval \"${cmd}\"`);
  if (!shellReturn.rc) {
    if (shellReturn.out) {
      common.printFormattedDebug("ZWELS", origin, `${stringlib.paddingLeft(shellReturn.out)} - )`);
    } else {
      common.printFormattedTrace("ZWELS", origin, "- Passed.");
    }
  } else {
    common.printFormattedTrace("ZWELS", origin, `- Failed with exit code ${shellReturn.rc}`);
    if (shellReturn.err) {
      common.printFormattedError("ZWELS", origin, `${stringlib.paddingLeft(shellReturn.err)} - )`);
    }
  }

  let prevErr = std.getenv("ZWE_PRIVATE_ERRORS_FOUND");
  let prevErrCount = !prevErr ? 0 : Number(prevErr);
  if (shellReturn.rc) {
    std.setenv("ZWE_PRIVATE_ERRORS_FOUND",prevErr+1);
  }
  return shellReturn.rc;
}

export function checkRuntimeValidationResult(origin: string) {
  // Summary errors check, exit if errors found
  let prevErr = std.getenv("ZWE_PRIVATE_ERRORS_FOUND");
  let prevErrCount = !prevErr ? 0 : Number(prevErr);
  if ( prevErrCount > 0) {
    common.printFormattedWarn("ZWELS", origin,  `${prevErrCount} errors were found during validation, please check the message, correct any properties required in ${std.getenv('ZWE_CLI_PARAMETER_CONFIG')} and re-launch Zowe.`);
    std.exit(std.getenv('ZWE_PRIVATE_ERRORS_FOUND'));
  }
}
