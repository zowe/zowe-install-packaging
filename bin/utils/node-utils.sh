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

#TODO LATER - provide flag that toggles all functions to error if they exit non-zero?

# Try and work out where we are even if sourced
if [[ -n ${ZOWE_ROOT_DIR} ]]
then
  export utils_dir="${ZOWE_ROOT_DIR}/bin/utils"
elif [[ -n ${ROOT_DIR} ]]
then
  export utils_dir="${ROOT_DIR}/bin/utils"
elif [[ $0 == "node-utils.sh" ]] #Not called by source
then
  export utils_dir=$(cd $(dirname $0);pwd)
else
  echo "Could not work out the path to the utils directory. Please 'export ZOWE_ROOT_DIR=<zowe-install-directory' before running." 1>&2
fi

ensure_node_is_on_path() {
  if [[ ":$PATH:" != *":$NODE_HOME/bin:"* ]]
  then
    echo "Appending NODE_HOME/bin to the PATH..."
    export PATH=$PATH:$NODE_HOME/bin
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

  NODE_OK=`${NODE_HOME}/bin/node -e "console.log('ok')" 2>&1`
  if [[ ${NODE_OK} == "ok" ]]
  then
    echo "OK: Node is working"
  else
    print_error_message "NODE_HOME: ${NODE_HOME}/bin/node is not functioning correctly: ${NODE_OK}"
    return 1
  fi

  NODE_MIN_VERSION=6.14
  NODE_VERSION=`${NODE_HOME}/bin/node --version` 
  NODE_VERSION_TRIMMED=`${NODE_HOME}/bin/node --version | sed 's/^.\{1\}//' | cut -d. -f1,2 2>&1`
  if [[ $NODE_VERSION = "v8.16.1" ]];
  then
    print_error_message "NODE Version 8.16.1 is not compatible with Zowe. Please use a different version. See https://docs.zowe.org/stable/troubleshoot/app-framework/app-known-issues.html#desktop-apps-fail-to-load for more details";
  elif [[ `echo "$NODE_VERSION_TRIMMED $NODE_MIN_VERSION" | awk '{print ($1 < $2)}'` == 1 ]];
  then
    print_error_message "NODE Version ${NODE_VERSION_TRIMMED} is less than minimum level required of ${NODE_MIN_VERSION}";
  else
    echo "OK: Node is at a supported version"
  fi

}

validate_node_home_not_empty() {
  . ${utils_dir}/zowe-variable-utils.sh
  validate_variable_is_set "NODE_HOME" "${NODE_HOME}"
  return $?
}

# TODO - refactor this into shared script?
# Note requires #ROOT_DIR to be set to use errror.sh, otherwise falls back to stderr
print_error_message() {
  message=$1
  error_path=${ROOT_DIR}/scripts/utils/error.sh
  if [[ -f "${error_path}" ]]
  then
    . ${error_path} $message
  else 
    echo $message 1>&2
  fi
}