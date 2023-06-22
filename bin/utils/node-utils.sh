#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

minVersion=14

# TODO LATER - anyway to do this better?
# Try and work out where we are even if sourced
if [[ -n ${INSTALL_DIR} ]]
then
  export utils_dir="${INSTALL_DIR}/bin/utils"
elif [[ -n ${ZOWE_ROOT_DIR} ]]
then
  export utils_dir="${ZOWE_ROOT_DIR}/bin/utils"
elif [[ -n ${ROOT_DIR} ]]
then
  export utils_dir="${ROOT_DIR}/bin/utils"
elif [[ $0 == "node-utils.sh" ]] #Not called by source
then
  export utils_dir=$(cd $(dirname $0);pwd)
else
  echo "Could not work out the path to the utils directory. Please 'export ZOWE_ROOT_DIR=<zowe-root-directory>' before running." 1>&2
  return 1
fi

# Source common util functions
. ${utils_dir}/common.sh

# TODO - how to test well given interaction and guess?
# Interactive function that checks if the current NODE_HOME is valid and if not requests a user enters the node home path via command line
prompt_for_node_home_if_required() {
  # If NODE_HOME not set, guess a default value
  if [[ -z ${NODE_HOME} ]]
  then
    NODE_HOME="/usr/lpp/IBM/cnj/IBM/node-latest-os390-s390x"
  fi
  loop=1
  while [ ${loop} -eq 1 ]
  do
    loop=0 # only want to re-run if user re-prompts
    validate_node_home # Note - this outputs messages for errors found
    node_valid_rc=$?
    if [[ ${node_valid_rc} -ne 0 ]]
    then
      echo "Press Y or y to accept current node home '${NODE_HOME}', or Enter to choose another location"
      read rep
      if [ "$rep" != "Y" ] && [ "$rep" != "y" ]
      then
        echo "Please enter a path to where node is installed.  This is the a directory that contains /bin/node "
        read NODE_HOME
        loop=1
      fi
    fi
  done
  export NODE_HOME=$NODE_HOME
  log_message "  NODE_HOME variable value=${NODE_HOME}"
}

ensure_node_is_on_path() {
  if [[ ":$PATH:" != *":$NODE_HOME/bin:"* ]]
  then
    print_message "Prepending NODE_HOME/bin to the PATH..."
    export PATH=$NODE_HOME/bin:$PATH
  fi
}

detect_node_home() {
  # do we have which?
  node_home=$(which node 2>/dev/null)
  node_home=
  if [ -z "${node_home}" ]; then
    (
      IFS=:
      for p in ${PATH}; do
        if [ -f "${p}/node" ]; then
          cd "${p}/.."
          pwd
          break
        fi
      done
    )
  else
    echo "${node_home}"
  fi
}

validate_node_home() {
  validate_node_home_not_empty
  node_empty_rc=$?
  if [[ ${node_empty_rc} -ne 0 ]]
  then
    return ${node_empty_rc}
  fi

  ls ${NODE_HOME}/bin | grep node$ > /dev/null
  if [[ $? -ne 0 ]];
  then
    print_error_message "NODE_HOME: ${NODE_HOME}/bin does not point to a valid install of Node"
    return 1
  fi

  node_version=$(${NODE_HOME}/bin/node --version 2>&1 ) # Capture stderr to stdout, so we can print below if error
  node_version_rc=$?
  if [[ ${node_version_rc} -ne 0 ]]
  then
    print_error_message "Node version check failed with return code: ${node_version_rc}, error: ${node_version}"
    return 1
  fi

  check_node_version "${node_version}"
  node_version_rc=$?
  if [[ ${node_version_rc} -ne 0 ]]
  then
    return ${node_version_rc}
  fi

  check_node_functional
  node_functional_rc=$?
  return ${node_functional_rc}
}

validate_node_home_not_empty() {
  . ${utils_dir}/zowe-variable-utils.sh
  validate_variable_is_set "NODE_HOME"
  return $?
}

# Given a node version from the `node --version` command, checks if it is valid
check_node_version() {
  node_version=$1
  current_year=$(date +"%Y")
  current_month=$(date +"%m")

  if [ "${node_version}" = "v14.17.2" ]
  then
    print_error_message "Node ${node_version} specifically is not compatible with Zowe. Please use a different version. See https://docs.zowe.org/stable/troubleshoot/app-framework/app-known-issues.html#desktop-apps-fail-to-load for more details."
    return 1
  fi

  node_major_version=$(echo ${node_version} | cut -d '.' -f 1 | cut -d 'v' -f 2)
  node_minor_version=$(echo ${node_version} | cut -d '.' -f 2)
  node_fix_version=$(echo ${node_version} | cut -d '.' -f 3)
  
  too_low=""
  too_low_support=""
  if [[ ${node_major_version} -lt ${minVersion} ]]
  then
    too_low="true"
  fi

  if [[ ${too_low} == "true" ]]
  then
    print_error_message "Node ${node_version} is less than the minimum level required of v14+"
    return 1
  else
    log_message "Node ${node_version} is supported."
  fi
}

check_node_functional() {
  log_message "Validating if node bin is functional..."
  node_ok=`${NODE_HOME}/bin/node -e "console.log('ok')" 2>&1`
  if [[ ${node_ok} == "ok" ]]
  then
    log_message "Node bin is functional"
  else
    print_error_message "NODE_HOME: ${NODE_HOME}/bin/node is not functioning correctly: ${node_ok}"
    return 1
  fi
}
