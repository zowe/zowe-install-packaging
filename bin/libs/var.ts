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
export function parseStringVars() {
  eval "echo \"${1}\""
}

// return value of the variable
export function getVarValue() {
  eval "echo \"\${${1}}\""
}

// get all environment variable exports line by line
export function get_environment_exports() {
  export -p | \
    grep -v -E '^export (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD=|PS1=|ENV=|LS_COLORS=|_=)' | \
    grep -v -E '^declare -x (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD|PS1=|ENV=|LS_COLORS=|_=)'
}

###############################
# get all environment variable exports line by line
export function get_environments() {
  export -p | \
    grep -v -E '^export (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD=|PS1=|ENV=|LS_COLORS=|_=)' | \
    grep -v -E '^declare -x (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD|PS1=|ENV=|LS_COLORS=|_=)' | \
    sed -e 's#^export ##' | \
    sed -e 's#^declare -x ##'
}

###############################
# Shell sourcing an environment env file
#
# All variables defined in env file will be exported.
#
# @param string   env file name
export function source_env() {
  env_file="${1}"

  . "${env_file}"

  while read -r line ; do
    # skip line if first char is #
    test -z "${line%%#*}" && continue
    key=${line%%=*}
    export $key
  done < "${env_file}"
}

# Takes in a single parameter - the name of the variable
export function is_variable_set() {
  variable_name="${1}"
  message="${2}"
  if [ -z "${message}" ]; then
    message="${variable_name} is not defined or empty."
  fi

  value=$(get_var_value "${variable_name}")
  if [ -z "${value}" ]; then
    print_error "${message}"
    return 1
  fi
}

# Takes in a list of space separated names of the variables
export function are_variables_set() {
  invalid=0

  for var in $(echo $1 | sed "s/,/ /g"); do
    is_variable_set "${var}"
    valid_rc=$?
    if [ ${valid_rc} -ne 0 ]; then
      let "invalid=${invalid}+1"
    fi
  done

  return ${invalid}
}

export function validate_this() {
  cmd="${1}"
  origin="${2}"

  print_formatted_trace "ZWELS" "${origin}" "Validate: ${cmd}"
  result=$(eval "${cmd}")
  retval=$?
  if [ "${retval}" = "0" ]; then
    if [ -n "${result}" ]; then
      print_formatted_debug "ZWELS" "${origin}" "$(padding_left "${result}" "- ")"
    else
      print_formatted_trace "ZWELS" "${origin}" "- Passed."
    fi
  else
    print_formatted_trace "ZWELS" "${origin}" "- Failed with exit code ${retval}"
    if [ -n "${result}" ]; then
      print_formatted_error "ZWELS" "${origin}" "$(padding_left "${result}" "- ")"
    fi
  fi

  let "ZWE_PRIVATE_ERRORS_FOUND=${ZWE_PRIVATE_ERRORS_FOUND}+${retval}"

  return ${retval}
}

export function check_runtime_validation_result() {
  origin="${1}"

  # Summary errors check, exit if errors found
  if [ ${ZWE_PRIVATE_ERRORS_FOUND} -gt 0 ]; then
    print_formatted_warn "ZWELS" "${origin}" "${ZWE_PRIVATE_ERRORS_FOUND} errors were found during validation, please check the message, correct any properties required in ${ZWE_CLI_PARAMETER_CONFIG} and re-launch Zowe."
    exit ${ZWE_PRIVATE_ERRORS_FOUND}
  fi
}
