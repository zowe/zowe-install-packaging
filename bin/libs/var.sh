#!/bin/sh

#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

###############################
# Check if a shell function is defined
#
# @param string   function name
# @output         true if the function is defined
function_exists() {
  fn=$1
  status=$(LC_ALL=C type $fn 2>&1 | grep 'function')
  if [ -n "${status}" ]; then
    echo "true"
  fi
}

###############################
# if a string has any env variables, replace them with values
parse_string_vars() {
  eval "echo \"${1}\""
}

###############################
# get all environment variable exports line by line
get_environment_exports() {
  export -p | \
    grep -v -E '^export (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD=|PS1=|ENV=|LS_COLORS=|_=)' | \
    grep -v -E '^declare -x (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD|PS1=|ENV=|LS_COLORS=|_=)'
}

###############################
# get all environment variable exports line by line
get_environments() {
  export -p | \
    grep -v -E '^export (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD=|PS1=|ENV=|LS_COLORS=|_=)' | \
    grep -v -E '^declare -x (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD|PS1=|ENV=|LS_COLORS=|_=)' | \
    sed -e 's#^export ##' | \
    sed -e 's#^declare -x ##'
}
