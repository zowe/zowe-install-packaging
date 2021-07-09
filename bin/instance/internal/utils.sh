#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2021
################################################################################

# where we store temporary environment files
if [ -z "${ZWELS_INSTANCE_ENV_DIR}" ]; then
  ZWELS_INSTANCE_ENV_DIR=${INSTANCE_DIR}/.env
fi
export ZWELS_INSTANCE_ENV_DIR
# how we read configurations
ZWELS_CONFIG_LOAD_METHOD=
if [ -n "${INSTANCE_DIR}" -a -f "${INSTANCE_DIR}/instance.env" ]; then
  ZWELS_CONFIG_LOAD_METHOD=instance.env
elif [ -n "${INSTANCE_DIR}" -a -f "${INSTANCE_DIR}/zowe.yaml" ]; then
  ZWELS_CONFIG_LOAD_METHOD=zowe.yaml
else
  ZWELS_CONFIG_LOAD_METHOD=
fi
export ZWELS_CONFIG_LOAD_METHOD

###############################
# Dummy function to check if this utils script has been sourced
#
# example: [ -z "$(is_instance_utils_sourced 2>/dev/null || true)" ] && echo "sourced"
is_instance_utils_sourced() {
  echo 'true'
}

###############################
# Check if a shell function is defined
#
# @param string   function name
# Output          true if the function is defined
function_exists() {
  fn=$1
  status=$(LC_ALL=C type $fn 2>&1 | grep 'function')
  if [ -n "${status}" ]; then
    echo "true"
  fi
}

###############################
# Exit script with error message
#
# @param string   error message
exit_with_error() {
  message=$1
  stack=$2

  if [ "$(function_exists print_formatted_error)" = "true" ]; then
    if [ -z "${stack}" ]; then
      stack="instance/bin/internal/utils.sh,exit_with_error:${LINENO}"
    fi
    print_formatted_error "ZWELS" "${stack}" "${message}"
  else
    >&2 echo "Error: ${message}"
  fi
  exit 1
}

###############################
# Shell sourcing an environment env file
#
# All variables defined in env file will be exported.
#
# @param string   env file name
source_env() {
  env_file=$1

  . "${env_file}"

  while read -r line ; do
    # skip line if first char is #
    test -z "${line%%#*}" && continue
    key=${line%%=*}
    export $key
  done < "${env_file}"
}

###############################
# Read YAML configuration from shell script
#
# Note: this is not a reliable way to read YAML file, but we need this to find
#       out ROOT_DIR to execute further functions.
#
# FIXME: we should have a language neutral YAML reading tool, not using shell script.
#
# @param string   YAML file name
# @param string   parent key to read after
# @param string   which key to read
# @param string   if this variable is required. If this is true and we cannot
#                 find the value of the key, an error will be displayed.
shell_read_yaml_config() {
  yaml_file=$1
  parent_key=$2
  key=$3
  required=$4

  val=$(cat "${yaml_file}" | awk "/${parent_key}:/{x=NR+2000;next}(NR<=x){print}" | grep "${key}" | head -n 1 | awk -F: '{print $2;}' | tr -d '[[:space:]]' | sed -e 's/^"//' -e 's/"$//')
  if [ -z "${val}" ]; then
    if [ "${required}" = "true" ]; then
      exit_with_error "cannot find ${parent_key}.${key} defined in $(basename $yaml_file)" "instance/bin/internal/utils.sh,shell_read_yaml_config:${LINENO}"
    fi
  else
    echo "${val}"
  fi
}

###############################
# Read the most basic variables we need to start Zowe
# - ROOT_DIR
# - ZOWE_PREFIX
# - ZOWE_INSTANCE
# - KEYSTORE_DIRECTORY?
# - ZWE_LOG_LEVEL_ZWELS?
# - NODE_HOME?
read_essential_vars() {
  if [ -z "${INSTANCE_DIR}" ]; then
    exit_with_error "INSTANCE_DIR does not have a value." "instance/bin/internal/utils.sh,read_essential_vars:${LINENO}"
  fi

  if [ "${ZWELS_CONFIG_LOAD_METHOD}" = "instance.env" ]; then
    source_env "${INSTANCE_DIR}/instance.env"
  elif [ "${ZWELS_CONFIG_LOAD_METHOD}" = "zowe.yaml" ]; then
    export ROOT_DIR=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "zowe" "runtimeDirectory" "true")
    export ZOWE_ROOT_DIR="${ROOT_DIR}"
    export ZOWE_PREFIX=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "zowe" "jobPrefix" "true")
    export ZOWE_INSTANCE=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "zowe" "identifier" "true")
    export KEYSTORE_DIRECTORY=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "environments" "KEYSTORE_DIRECTORY" "false")
    # this could get wrong value if launchScript doesn't have logLevel defined, but something else has
    ZWE_LOG_LEVEL_ZWELS=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "launchScript" "logLevel" "false")
    if [ -z "${ZWE_LOG_LEVEL_ZWELS}" ]; then
      ZWE_LOG_LEVEL_ZWELS=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "environments" "ZWE_LOG_LEVEL_ZWELS" "false")
    fi
    export ZWE_LOG_LEVEL_ZWELS
    # find node_home, this is needed for config converter tools
    zowe_node_home=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "node" "home" "false")
    if [ ! -z "${zowe_node_home}" ]; then
      export NODE_HOME=${zowe_node_home}
    fi
  else
    exit_with_error "cannot find either instance.env or zowe.yaml in instance directory" "instance/bin/internal/utils.sh,read_essential_vars:${LINENO}"
  fi
}
