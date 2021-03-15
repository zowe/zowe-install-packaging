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

export INSTANCE_ENV_DIR=${INSTANCE_DIR}/.env

function_exists() {
  fn=$1
  status=$(LC_ALL=C type $n | grep -q 'shell function')
  if [ -n "${status}" ]; then
    echo "true"
  fi
}

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

# get system name
get_sysname() {
  sysname=$(sysvar SYSNAME 2>/dev/null)
  if [ -z ${sysname} ]; then
    sysname=$(hostname -s 2>/dev/null)
  fi
  echo "${sysname}" | tr '[:upper:]' '[:lower:]'
}

is_on_zos() {
  if [ `uname` = "OS/390" ]; then
    echo "true"
  else
    echo "false"
  fi
}

zos_get_file_tag_encoding() {
  file=$1
  # m ISO8859-1   T=off <file>
  # - untagged    T=off <file>
  ls -T "$file" | awk '{print $2;}' | tr '[:lower:]' '[:upper:]'
}

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

  if [ -f "${INSTANCE_DIR}/instance.env" ]; then
    source_env "${INSTANCE_DIR}/instance.env"
  elif [ -f "${INSTANCE_DIR}/zowe.yaml" ]; then
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

# prepare env directory, which should be owned by runtime user
reset_env_dir() {
  rm -fr "${INSTANCE_ENV_DIR}" 2>/dev/null
  mkdir -p "${INSTANCE_ENV_DIR}"
  chmod 750 "${INSTANCE_ENV_DIR}"
}

# this is here because config-converter requires node.js
prepare_node_js() {
  . "${ROOT_DIR}/bin/utils/node-utils.sh"
  ensure_node_is_on_path 1>/dev/null 2>&1
}

convert_instance_env_to_yaml() {
  node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" env yaml "${INSTANCE_DIR}/instance.env" > "${INSTANCE_ENV_DIR}/zowe.yaml"
  chmod 640 "${INSTANCE_ENV_DIR}/zowe.yaml"
}

prepare_yaml_for_ha_instance() {
  yaml_file=$1
  ha_instance=$2
  node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" yaml convert --wd "${INSTANCE_ENV_DIR}" --ha "${ha_instance}" "${yaml_file}"
}

convert_yaml_to_instance_env() {
  ha_instance=$1
  node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" yaml env --wd "${INSTANCE_ENV_DIR}" --ha "${ha_instance}"
}

convert_env_dir_file_encoding() {
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

# node.js may create instance.env with ISO8859-1, need to convert to IBM-1047 to allow shell to read
fix_env_dir_files_encoding() {
  if [ "$(is_on_zos)" != "true" ]; then
    return 0
  fi
  for one in $(find "${INSTANCE_ENV_DIR}" -type f -name '.instance-*.env') ; do
    convert_env_dir_file_encoding "${one}"
  done
}

prepare_instance_env_from_yaml_config() {
  ha_instance=$1

  if [ -f "${INSTANCE_DIR}/instance.env" -o ! -f "${INSTANCE_DIR}/zowe.yaml" ]; then
    # still using instance.env, nothing to do
    return 0
  fi

  prepare_node_js
  prepare_yaml_for_ha_instance "${INSTANCE_DIR}/zowe.yaml" "${ha_instance}"
  if [ ! -f "${INSTANCE_ENV_DIR}/.zowe.yaml" ]; then
    exit_with_error "failed to translate <instance-dir>/zowe.yaml"
  fi
  convert_yaml_to_instance_env "${ha_instance}"
  fix_env_dir_files_encoding
  if [ -f "${INSTANCE_ENV_DIR}/gateway/.manifest.json" ]; then
    # component manifest already in place, we don't need to run this again
    touch "${INSTANCE_ENV_DIR}/.ready"
  fi
}

prepare_and_read_instance_env() {
  ha_instance=$1
  component_id=$2

  print_formatted=$(function_exists print_formatted_info)
  LOGGING_SERVICE_ID=ZWELS
  LOGGING_SCRIPT_NAME=prepare_and_read_instance_env

  if [ -z "${ha_instance}" ]; then
    ha_instance=$(get_sysname)
  fi
  if [ ! -f "${INSTANCE_ENV_DIR}/.zowe.yaml" ]; then
    # never initialized, do minimal
    message="initialize instance-<ha-id>.env"
    if [ "${print_formatted}" = "true" ]; then
      print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${message}"
    else
      echo "${message}"
    fi
    prepare_instance_env_from_yaml_config "${ha_instance}"
  elif [ ! -f "${INSTANCE_ENV_DIR}/.ready" ]; then
    if [ -f "${INSTANCE_ENV_DIR}/gateway/.manifest.json" ]; then
      message="refresh component copy of instance.env(s)"
      if [ "${print_formatted}" = "true" ]; then
        print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${message}"
      else
        echo "${message}"
      fi
      prepare_instance_env_from_yaml_config "${ha_instance}"
    fi
  fi
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
    exit_with_error "failed to translate zowe.yaml"
  fi
}
