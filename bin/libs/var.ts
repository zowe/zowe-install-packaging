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

import * as common from './common';
import * as shell from './shell';
import * as stringlib from './string';

// internal errors counter for validations
std.setenv('ZWE_PRIVATE_ERRORS_FOUND', '0');

// Check if a shell function is defined
export function functionExists(fn: string): boolean {
  let lcAll=std.getenv('LC_ALL'); 
  std.setenv('LC_ALL', 'C');
  let shellReturn = shell.execOutSync('type', fn);// 2>&1 | grep 'function')
  if (lcAll){
    std.setenv('LC_ALL', lcAll);
  } else {
    std.unsetenv('LC_ALL');
  }
  
  if (shellReturn.out) {
    return shellReturn.out.split('\n')[0].endsWith('function');
  }
  return false;
}

/* 
${var#Pattern}, ${var##Pattern}

    ${var#Pattern} Remove from $var the shortest part of $Pattern that matches the front end of $var.

    ${var##Pattern} Remove from $var the longest part of $Pattern that matches the front end of $var. 

*/

export function resolveShellVariable(previousKey: string, currentKey: string, currentValue: string|undefined, modifier: string): string|undefined {
  switch (modifier) {
  //${parameter-default}, ${parameter:-default}
  //  If parameter not set, use default.
  case '-': {
    return currentValue ? currentValue : currentKey;
  }
  //${parameter+alt_value}, ${parameter:+alt_value}
  //  If parameter set, use alt_value, else use null string.
  case '+': {
    return std.getenv(previousKey) ? currentKey : 'null';
  }
  //${parameter?err_msg}, ${parameter:?err_msg}
  //  If parameter set, use it, else print err_msg and abort the script with an exit status of 1.
  case '?': {
    let prev;
    if ((prev=std.getenv(previousKey))) {
      return prev;
    } else {
      common.printError(currentKey);
      return currentValue;
    }
  }
  //${parameter=default}, ${parameter:=default}
  //  If parameter not set, set it to default.
  case '=': {
    if (!std.getenv(previousKey)) {
      std.setenv(previousKey, std.getenv(currentKey));
    }
    return std.getenv(previousKey);
  }
  default:
    return undefined;
  }
}



// if a string has any env variables, replace them with values
//
// TODO this does not seem to handle cases such as ${thing:-${thing:-default}} where 1 var is nested inside another.
// That appears to need sensing of which } is the right one to end on, and recursion upon seeing a $ in the -=+? while loop.
export function resolveShellTemplate(content: string): string|undefined {
  let position = 0;
  let output = '';
  
  while (position != -1 && position < content.length) {
    let index = content.indexOf('$', position);
    if (index == -1) {
      output+=content.substring(position);
      return output;
    } else {
      output+=content.substring(position, index);
      if (content[index+1] === '{') {
        let endIndex = content.indexOf('}', index+2);
        if (endIndex == -1) {
          output+=content.substring(position);
          return output;
        }
        
        //${#var}
        //  String length (number of characters in $var). For an array, ${#array} is the length of the first element in the array.
        if (content[index+2] === '#') {
          let value = std.getenv(content.substring(index+3, endIndex));
          if (value!==undefined) {
            output+=value.length;
            position=endIndex;
            continue;
          }
        }

        let accumIndex = index+2;
        let currentIndex = index+2;
        let envValue:string;
        let firstKey:string;
        let previousKey=null;
        let currentKey:string;
        let previousModifier;
        while ((currentIndex<endIndex) && (envValue===undefined)) {
          const char = content[currentIndex];
          if (char == '-' || char == '=' || char == '+' || char == '?') {
            currentKey=content.substring(accumIndex, currentIndex);
            if (currentKey.endsWith(':')) {
              //TODO this does not handle : cases different from non-: cases, unsure what to do with them
              currentKey = currentKey.substring(0,currentKey.length-1);
            }
            accumIndex=currentIndex+1;
            if (currentKey) {
              if (firstKey===undefined) {
                firstKey=currentKey;
                envValue=std.getenv(firstKey);
              }
            }
            if (previousModifier) {
              envValue = resolveShellVariable(previousKey, currentKey, envValue, previousModifier);
            }
            previousKey=currentKey;
            previousModifier = char;
          }
          currentIndex++;
        }
        
        currentKey=content.substring(accumIndex, currentIndex);
        if (currentKey.endsWith(':')) {
          //TODO this does not handle : cases different from non-: cases, unsure what to do with them
          currentKey = currentKey.substring(0,currentKey.length-1);
        }
        if (currentKey) {
          if (firstKey===undefined) {
            firstKey=currentKey;
            envValue=std.getenv(firstKey);
          }
        }
        if (previousModifier) {
          envValue = resolveShellVariable(previousKey, currentKey, envValue, previousModifier);
        }
        if (envValue!==undefined) {
          output+=envValue;
        }
        position=endIndex+1;
      } else {
        let keyIndex = index+1;
        let charCode = content.charCodeAt(keyIndex);

        while ((keyIndex<content.length)
          && ((charCode <0x5b && charCode > 0x40)
            || (charCode < 0x7b && charCode > 0x60)
            || (charCode > 0x2f && charCode < 0x40)
            || (charCode == 0x5f))) {

          charCode = content.charCodeAt(++keyIndex);
        }
        let val = std.getenv(content.substring(index+1, keyIndex));
        if (val!==undefined) {
          output+=val;
        }
        position=keyIndex;
      }
    }
  }
  return output;
}

// return value of the variable
export function getVarValue(key: string): string {
  return `\$\{${std.getenv(key)}`;
}

// get all environment variable exports line by line
const exportFilter=/^export (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD=|PS1=|ENV=|LS_COLORS=|_=)/
const declareFilter=/^declare -x (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD|PS1=|ENV=|LS_COLORS=|_=)/

const keyFilter=/^(run_zowe_start_component_id|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file|key|line|service|logger|level|expected_log_level_val|expected_log_level_var|display_log|message|utils_dir|print_formatted_function_available|LINENO|ENV|opt|OPTARG|OPTIND|LOGNAME|USER|SSH_|SHELL|PWD|OLDPWD|PS1|ENV|LS_COLORS|_)$/

export function getEnvironmentExports(input?:string, doExport?: boolean): string {
  let exports:string[]=[];
  if (!input) {
    let envvars = std.getenviron();
    let keys = Object.keys(envvars);
    keys.forEach((key: string)=> {
      if (!keyFilter.test(key)) {
        exports.push(`export ${key}=${envvars[key]}`);
      }
    });
  } else {
    const lines = input.split('\n');
    lines.forEach((line:string)=> {
      if ((line.startsWith('export ') || line.startsWith('declare -x ')) && (!exportFilter.test(line) && !declareFilter.test(line))) {
        exports.push(line);
        if (doExport) {
          setExport(line);
        }
      }
    });
  }
  return exports.join('\n');
}

// get all environment variable exports line by line
export function getEnvironments(): string {
  let envvars = std.getenviron();
  let keys = Object.keys(envvars);
  let exports:string[]=[];
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
  
  let fileContents = xplatform.loadFileUTF8(envFile,xplatform.AUTO_DETECT);
  return setExports(fileContents);
}

export function setExports(envFileContents: string): boolean {
  let fileLines = envFileContents.split('\n');
  fileLines.forEach((line: string)=> {
    setExport(line);
  });
  return true;
}

export function setExport(envFileLine: string): boolean {
  let index: number;

  if ((index = envFileLine.indexOf('=')) != -1) {
    let key: string;
    if (envFileLine.startsWith('export ')) {
      key = envFileLine.substring(7, index);
    } else if (envFileLine.startsWith('declare -x ')) {
      key = envFileLine.substring(11, index);
    } else if (envFileLine.startsWith('set ')) {
      key = envFileLine.substring(4, index);
    } else {
      key = envFileLine.substring(0, index);
    }
    if ((envFileLine[index+1] == "'" && envFileLine.endsWith("'")) || (envFileLine[index+1] == '"' && envFileLine.endsWith('"'))) {
      let val = envFileLine.substring(index + 2, envFileLine.length-1);
      std.setenv(key, val);
      common.printTrace(`Set env var ${key} to ${val}`);
      return true;
    } else {
      let val = envFileLine.substring(index + 1);
      std.setenv(key, val);
      common.printTrace(`Set env var ${key} to ${val}`);
      return true;
    }
  }
  return false;
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
  let shellReturn = shell.execOutErrSync('sh', `eval`, `\"${cmd}\"`);
  if (!shellReturn.rc) {
    if (shellReturn.out) {
      common.printFormattedDebug("ZWELS", origin, stringlib.paddingLeft(shellReturn.out, '- '));
    } else {
      common.printFormattedTrace("ZWELS", origin, "- Passed.");
    }
  } else {
    common.printFormattedTrace("ZWELS", origin, `- Failed with exit code ${shellReturn.rc}`);
    if (shellReturn.err) {
      common.printFormattedError("ZWELS", origin, stringlib.paddingLeft(shellReturn.err, '- '));
    }
  }

  let prevErr = std.getenv("ZWE_PRIVATE_ERRORS_FOUND");
  let prevErrCount = !prevErr ? 0 : Number(prevErr);
  if (shellReturn.rc) {
    prevErrCount++;
    std.setenv("ZWE_PRIVATE_ERRORS_FOUND",''+prevErrCount);
  }
  return shellReturn.rc;
}

export function checkRuntimeValidationResult(origin: string) {
  // Summary errors check, exit if errors found
  let prevErr = std.getenv("ZWE_PRIVATE_ERRORS_FOUND");
  let prevErrCount = !prevErr ? 0 : Number(prevErr);
  if ( prevErrCount > 0) {
    common.printFormattedWarn("ZWELS", origin,  `${prevErrCount} errors were found during validation, please check the message, correct any properties required in ${std.getenv('ZWE_CLI_PARAMETER_CONFIG')} and re-launch Zowe.`);
    std.exit(prevErrCount ); 
  }
}
