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

################################################################################
# @internal 

###############################
# Check encoding of a file and convert to IBM-1047 if needed.
#
# Note: usually this is required if the file is supposed to be shell script,
#       which requires to be IBM-1047 encoding.
#
# @param string    file to check and convert
zos_convert_env_dir_file_encoding() {
  file="${1}"

  encoding=$(get_file_encoding "$file")
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>BEFORE ${file} encoding is ${encoding}"
  cat "$file"
  echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  if [ "${encoding}" != "UNTAGGED" -a "${encoding}" != "IBM-1047" ]; then
    tmpfile="${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/t"
    rm -f "${tmpfile}"
    iconv -f "${encoding}" -t "IBM-1047" "${file}" > "${tmpfile}"
    mv "${tmpfile}" "${file}"
    chmod 640 "${file}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>AFTER ${file}"
    ls -laT "${file}"
    cat "$file"
    echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  fi
}

###############################
# Prepare configuration for current HA instance, and generate backward
# compatible instance.env files from zowe.yaml.
#
# @param string   HA instance ID
generate_instance_env_from_yaml_config() {
  ha_instance="${1}"

  configmgr="${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr"
  generateEnv="${ZWE_zowe_runtimeDirectory}/bin/utils/GenerateInstanceEnv.js"

  print_message "- generate env for \"${ha_instance}\""
  result=$(_CEE_RUNOPTS="XPLINK(ON)" "${configmgr}" -script "$generateEnv" "$ha_instance" "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}" 2>&1)
  code=$?
  if [ ${code} -eq 0 ]; then
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    if [ -n "${result}" ]; then
      print_trace "$(padding_left "${result}" "    ")"
    fi
  else
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi
  fi
}

# check and sanitize ZWE_CLI_PARAMETER_HA_INSTANCE
sanitize_ha_instance_id() {
  # ignore default value passed from ZWESLSTC
  if [ "${ZWE_CLI_PARAMETER_HA_INSTANCE}" = "{{ha_instance_id}}" -o "${ZWE_CLI_PARAMETER_HA_INSTANCE}" = "__ha_instance_id__" ]; then
    ZWE_CLI_PARAMETER_HA_INSTANCE=
  fi
  if [ -z "${ZWE_CLI_PARAMETER_HA_INSTANCE}" ]; then
    ZWE_CLI_PARAMETER_HA_INSTANCE=$(get_sysname)
  fi
  # sanitize instance id
  ZWE_CLI_PARAMETER_HA_INSTANCE=$(echo "${ZWE_CLI_PARAMETER_HA_INSTANCE}" | lower_case | sanitize_alphanum)
}

###############################
# Load environment variables used by components
#
# NOTE: all environment variables used/defined by Zowe should be ensured in this function.
#       "zwe internal start prepare" is the only special case where we may need to define some variables before calling
#       this function. The reason is to properly prepare the directories, logging, etc.
load_environment_variables() {
  component_id="${1}"

  # check and sanitize ZWE_CLI_PARAMETER_HA_INSTANCE
  sanitize_ha_instance_id

  if [ -z "${ZWE_zowe_workspaceDirectory}" ]; then
    ZWE_zowe_workspaceDirectory=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" '.zowe.workspaceDirectory')
    if [ -z "${ZWE_zowe_workspaceDirectory}" ]; then
      print_error_and_exit "Error ZWEL0157E: Zowe workspace directory (zowe.workspaceDirectory) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi

  if [ -z "${ZWE_VERSION}" ]; then
    export ZWE_VERSION=$(shell_read_json_config "${ZWE_zowe_runtimeDirectory}/manifest.json" 'version' 'version')
  fi

  # we must have $ZWE_zowe_workspaceDirectory at this point
  if [ -f "${ZWE_zowe_workspaceDirectory}/.init-for-container" ]; then
    export ZWE_RUN_IN_CONTAINER=true
  fi

  # these are already set in prepare stage, re-ensure for start
  export ZWE_PRIVATE_WORKSPACE_ENV_DIR="${ZWE_zowe_workspaceDirectory}/.env"
  export ZWE_STATIC_DEFINITIONS_DIR="${ZWE_zowe_workspaceDirectory}/api-mediation/api-defs"
  export ZWE_GATEWAY_SHARED_LIBS="${ZWE_zowe_workspaceDirectory}/gateway/sharedLibs/"
  export ZWE_ZAAS_SHARED_LIBS="${ZWE_zowe_workspaceDirectory}/zaas/sharedLibs/"
  export ZWE_DISCOVERY_SHARED_LIBS="${ZWE_zowe_workspaceDirectory}/discovery/sharedLibs/"

  # now we can load all variables
  if [ -n "${component_id}" -a -f "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_id}/.instance-${ZWE_CLI_PARAMETER_HA_INSTANCE}.env" ]; then
    source_env "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_id}/.instance-${ZWE_CLI_PARAMETER_HA_INSTANCE}.env"
  elif [ -f "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/.instance-${ZWE_CLI_PARAMETER_HA_INSTANCE}.env" ]; then
    source_env "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/.instance-${ZWE_CLI_PARAMETER_HA_INSTANCE}.env"
  else
    print_error_and_exit "Error ZWEL0112E: Zowe runtime environment must be prepared first with \"zwe internal start prepare\" command." "" 112
  fi

  # ZWE_DISCOVERY_SERVICES_LIST should have been prepared in zowe-install-packaging-tools and had been sourced.

  # overwrite ZWE_PRIVATE_LOG_LEVEL_ZWELS with zowe.launchScript.logLevel config in YAML
  export ZWE_PRIVATE_LOG_LEVEL_ZWELS="$(echo "${ZWE_zowe_launchScript_logLevel}" | upper_case)"

  # generate other variables
  export ZWE_INSTALLED_COMPONENTS="$(find_all_installed_components)"
  export ZWE_ENABLED_COMPONENTS="$(find_all_enabled_components)"
  export ZWE_LAUNCH_COMPONENTS="$(find_all_launch_components)"

  # ZWE_DISCOVERY_SERVICES_LIST should have been prepared in zowe-install-packaging-tools

  if [ "${ZWE_RUN_IN_CONTAINER}" = "true" ]; then
    prepare_container_runtime_environments
  fi
}
