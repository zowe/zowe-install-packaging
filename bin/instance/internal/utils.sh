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
export INSTANCE_ENV_DIR=${INSTANCE_DIR}/.env
# how we read configurations
ZWE_CONFIG_LOAD_METHOD=
if [ -f "${INSTANCE_DIR}/instance.env" ]; then
  ZWE_CONFIG_LOAD_METHOD=instance.env
elif [ -f "${INSTANCE_DIR}/zowe.yaml" ]; then
  ZWE_CONFIG_LOAD_METHOD=zowe.yaml
else
  ZWE_CONFIG_LOAD_METHOD=
fi
export ZWE_CONFIG_LOAD_METHOD

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
  status=$(LC_ALL=C type $fn | grep 'function')
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

  if [ "$(function_exists print_formatted_error)" = "true" ]; then
    LOGGING_SERVICE_ID=ZWELS
    LOGGING_SCRIPT_NAME=exit_with_error
    print_formatted_error "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${message}"
  else
    >&2 echo "Error: ${message}"
  fi
  exit 1
}

###############################
# Return system name in lower case
#
# - value SYSNAME variable
# - short hostname
get_sysname() {
  sysname=$(sysvar SYSNAME 2>/dev/null)
  if [ -z "${sysname}" ]; then
    sysname=$(hostname -s 2>/dev/null)
  fi
  echo "${sysname}" | tr '[:upper:]' '[:lower:]'
}

###############################
# Check if script is running on z/OS
#
# Output          true if it's z/OS
is_on_zos() {
  if [ `uname` = "OS/390" ]; then
    echo "true"
  else
    echo "false"
  fi
}

###############################
# Get file encoding from z/OS USS tagging
#
# @param string   file name
# output          USS encoding if exists in upper case
zos_get_file_tag_encoding() {
  file=$1
  # m ISO8859-1   T=off <file>
  # - untagged    T=off <file>
  ls -T "$file" | awk '{print $2;}' | tr '[:lower:]' '[:upper:]'
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
      exit_with_error "cannot find ${parent_key}.${key} defined in $(basename $yaml_file)"
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
# - NODE_HOME?
read_essential_vars() {
  if [ -z "${INSTANCE_DIR}" ]; then
    exit_with_error "INSTANCE_DIR does not have a value."
  fi

  if [ "${ZWE_CONFIG_LOAD_METHOD}" = "instance.env" ]; then
    source_env "${INSTANCE_DIR}/instance.env"
  elif [ "${ZWE_CONFIG_LOAD_METHOD}" = "zowe.yaml" ]; then
    export ROOT_DIR=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "zowe" "runtimeDirectory" "true")
    export ZOWE_PREFIX=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "zowe" "jobPrefix" "true")
    export ZOWE_INSTANCE=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "zowe" "identifier" "true")
    export KEYSTORE_DIRECTORY=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "environments" "KEYSTORE_DIRECTORY" "false")
    # find node_home, this is needed for config converter tools
    zowe_node_home=$(shell_read_yaml_config "${INSTANCE_DIR}/zowe.yaml" "node" "home" "false")
    if [ ! -z "${zowe_node_home}" ]; then
      export NODE_HOME=${zowe_node_home}
    fi
  else
    exit_with_error "cannot find either instance.env or zowe.yaml in instance directory"
  fi
}

###############################
# Empty and prepare env directory, which should be owned by runtime user
reset_env_dir() {
  rm -fr "${INSTANCE_ENV_DIR}" 2>/dev/null
  mkdir -p "${INSTANCE_ENV_DIR}"
  chmod 750 "${INSTANCE_ENV_DIR}"
}

###############################
# Prepare NODE_HOME and PATH to execute node.js scripts
#
# Note: this is here because config-converter requires node.js.
prepare_node_js() {
  . "${ROOT_DIR}/bin/utils/node-utils.sh"
  ensure_node_is_on_path 1>/dev/null 2>&1
}

###############################
# Convert instance.env to zowe.yaml file
#
# FIXME: this is used for now.
convert_instance_env_to_yaml() {
  if [ "${ZWE_CONFIG_LOAD_METHOD}" != "instance.env" ]; then
    return 0
  fi

  node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" env yaml "${INSTANCE_DIR}/instance.env" > "${INSTANCE_ENV_DIR}/zowe.yaml"
  chmod 640 "${INSTANCE_ENV_DIR}/zowe.yaml"
}

###############################
# Check encoding of a file and convert to IBM-1047 if needed.
#
# Note: usually this is required if the file is supposed to be shell script,
#       which requires to be IBM-1047 encoding.
#
# @param string    file to check and convert
zos_convert_env_dir_file_encoding() {
  file=$1

  encoding=$(zos_get_file_tag_encoding "$one")
  if [ "${encoding}" != "UNTAGGED" -a "${encoding}" != "IBM-1047" ]; then
    tmpfile="${INSTANCE_ENV_DIR}/t"
    rm -f "${tmpfile}"
    iconv -f "${encoding}" -t "IBM-1047" "${file}" > "${tmpfile}"
    mv "${tmpfile}" "${file}"
    chmod 640 "${file}"
  fi
}

###############################
# Prepare configuration for current HA instance, and generate backward
# compatible instance.env files from zowe.yaml.
#
# @param string   HA instance ID
generate_instance_env_from_yaml_config() {
  ha_instance=$1

  if [ "${ZWE_CONFIG_LOAD_METHOD}" != "zowe.yaml" ]; then
    # still using instance.env, nothing to do
    return 0
  fi

  prepare_node_js

  # prepare .zowe.yaml and .zowe-<ha-id>.json
  node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" yaml convert --wd "${INSTANCE_ENV_DIR}" --ha "${ha_instance}" "${INSTANCE_DIR}/zowe.yaml"
  if [ ! -f "${INSTANCE_ENV_DIR}/.zowe.yaml" ]; then
    exit_with_error "failed to translate <instance-dir>/zowe.yaml"
  fi

  # convert YAML configurations to backward compatible .instance-<ha-id>.env files
  node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" yaml env --wd "${INSTANCE_ENV_DIR}" --ha "${ha_instance}"

  # fix files encoding
  # node.js may create instance.env with ISO8859-1, need to convert to IBM-1047 to allow shell to read
  if [ "$(is_on_zos)" = "true" ]; then
    for one in $(find "${INSTANCE_ENV_DIR}" -type f -name '.instance-*.env') ; do
      zos_convert_env_dir_file_encoding "${one}"
    done
  fi

  # we are all set
  if [ -f "${INSTANCE_ENV_DIR}/gateway/.manifest.json" ]; then
    # component manifest already in place, we don't need to run this again
    touch "${INSTANCE_ENV_DIR}/.ready"
  fi
}

###############################
# This script will source appropriate instance.env variables based on
# HA instance ID and component. If the instance.env doesn't exist, it
# will try to generate it.
generate_and_read_instance_env_from_yaml_config() {
  ha_instance=$1
  component_id=$2

  if [ "${ZWE_CONFIG_LOAD_METHOD}" != "zowe.yaml" ]; then
    # still using instance.env, nothing to do
    return 0
  fi

  print_formatted=$(function_exists print_formatted_info)
  LOGGING_SERVICE_ID=ZWELS
  LOGGING_SCRIPT_NAME=generate_and_read_instance_env_from_yaml_config

  if [ -z "${ha_instance}" ]; then
    exit_with_error "HA_INSTANCE_ID is empty"
  fi

  # usually creating instance.env has 2 steps:
  # 1. components .manifest.json are not ready yet, we can only generate <.env>/.instance-<ha-id>.env
  # 2. components .manifest.json are ready, we should also generate <.env>/<component>/.instance-<ha-id>.env
  # <.env>/.ready is indication where all conversions are completed, no need to re-run.

  if [ ! -f "${INSTANCE_ENV_DIR}/.zowe.yaml" ]; then
    # never initialized, do minimal
    message="initialize .instance-${ha_instance}.env"
    if [ "${print_formatted}" = "true" ]; then
      print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${message}"
    else
      echo "${message}"
    fi
    generate_instance_env_from_yaml_config "${ha_instance}"
  elif [ ! -f "${INSTANCE_ENV_DIR}/.ready" ]; then
    if [ -f "${INSTANCE_ENV_DIR}/gateway/.manifest.json" ]; then
      message="refresh component copy of .instance-${ha_instance}.env(s)"
      if [ "${print_formatted}" = "true" ]; then
        print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${message}"
      else
        echo "${message}"
      fi
      generate_instance_env_from_yaml_config "${ha_instance}"
    fi
  fi

  # try to source correct instance.env file
  if [ "${component_id}" != "" -a -f "${INSTANCE_ENV_DIR}/${component_id}/.instance-${ha_instance}.env" ]; then
    message="loading ${INSTANCE_ENV_DIR}/${component_id}/.instance-${ha_instance}.env"
    if [ "${print_formatted}" = "true" ]; then
      print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${message}"
    else
      echo "${message}"
    fi
    source_env "${INSTANCE_ENV_DIR}/${component_id}/.instance-${ha_instance}.env"
  elif [ -f "${INSTANCE_ENV_DIR}/.instance-${ha_instance}.env" ]; then
    message="loading ${INSTANCE_ENV_DIR}/.instance-${ha_instance}.env"
    if [ "${print_formatted}" = "true" ]; then
      print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${message}"
    else
      echo "${message}"
    fi
    source_env "${INSTANCE_ENV_DIR}/.instance-${ha_instance}.env"
  else
    # something wrong, conversion wasn't successful
    if [ "${component_id}" != "" ]; then
      message="compatible version of <instance>/.env/${component_id}/.instance-${ha_instance}.env doesnot exist"
    else
      message="compatible version of <instance>/.env/.instance-${ha_instance}.env doesnot exist"
    fi
    if [ "${print_formatted}" = "true" ]; then
      print_formatted_error "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${message}"
    else
      >&2 echo "Error: ${message}"
    fi
    exit 1
  fi
}
