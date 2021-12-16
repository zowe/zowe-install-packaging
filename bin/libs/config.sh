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
# Convert instance.env to zowe.yaml file
convert_instance_env_to_yaml() {
  instance_env=$1
  zowe_yaml=$2

  # we need node for following commands
  ensure_node_is_on_path 1>/dev/null 2>&1

  if [ -z "${zowe_yaml}" ]; then
    node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" env yaml "${instance_env}"
  else
    node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" env yaml "${instance_env}" -o "${zowe_yaml}"

    ensure_file_encoding "${zowe_yaml}" "zowe:" "IBM-1047"

    chmod 640 "${zowe_yaml}"
  fi
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
  ha_instance=$1

  # delete old files to avoid potential issues
  print_formatted_trace "ZWELS" "bin/libs/config.sh,generate_instance_env_from_yaml_config:${LINENO}" "deleting old files under ${ZWE_zowe_workspaceDirectory}/.env"
  find "${ZWE_zowe_workspaceDirectory}/.env" -type f -name ".*-${ha_instance}.env" | xargs rm -f
  find "${ZWE_zowe_workspaceDirectory}/.env" -type f -name ".*-${ha_instance}.json" | xargs rm -f
  find "${ZWE_zowe_workspaceDirectory}/.env" -type f -name ".zowe.yaml" | xargs rm -f

  # prepare .zowe.json and .zowe-<ha-id>.json
  print_formatted_trace "ZWELS" "bin/libs/config.sh,generate_instance_env_from_yaml_config:${LINENO}" "config-converter yaml convert --ha ${ha_instance} ${ZWE_CLI_PARAMETER_CONFIG}"
  result=$(node "${ZWE_zowe_runtimeDirectory}/bin/utils/config-converter/src/cli.js" yaml convert --wd "${ZWE_zowe_workspaceDirectory}/.env" --ha "${ha_instance}" "${ZWE_CLI_PARAMETER_CONFIG}" --verbose)
  code=$?
  print_formatted_trace "ZWELS" "bin/libs/config.sh,generate_instance_env_from_yaml_config:${LINENO}" "- Exit code: ${code}: ${result}"
  if [ ! -f "${ZWE_zowe_workspaceDirectory}/.env/.zowe.json" ]; then
    print_formatted_error "ZWELS" "bin/libs/config.sh,generate_instance_env_from_yaml_config:${LINENO}" "ZWEL0140E: Failed to translate Zowe configuration (${ZWE_CLI_PARAMETER_CONFIG})."
    exit 140
  fi

  # convert YAML configurations to backward compatible .instance-<ha-id>.env files
  print_formatted_trace "ZWELS" "bin/libs/config.sh,generate_instance_env_from_yaml_config:${LINENO}" "config-converter yaml env --ha ${ha_instance}"
  result=$(node "${ZWE_zowe_runtimeDirectory}/bin/utils/config-converter/src/cli.js" yaml env --wd "${ZWE_zowe_workspaceDirectory}/.env" --ha "${ha_instance}" --verbose)
  code=$?
  print_formatted_trace "ZWELS" "bin/libs/config.sh,generate_instance_env_from_yaml_config:${LINENO}" "- Exit code: ${code}: ${result}"
  if [ ! -f "${ZWE_zowe_workspaceDirectory}/.env/.instance-${ha_instance}.env" ]; then
    print_formatted_error "ZWELS" "bin/libs/config.sh,generate_instance_env_from_yaml_config:${LINENO}" "ZWEL0140E: Failed to translate Zowe configuration (${ZWE_CLI_PARAMETER_CONFIG})."
    exit 140
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

load_environment_variables() {
  component_id=$1

  # we must have $ZWE_zowe_workspaceDirectory at this time
  if [ -f "${ZWE_zowe_workspaceDirectory}/.init-for-container" ]; then
    export ZWE_RUN_IN_CONTAINER=true
  fi

  # now we can load all variables
  if [ -n "${component_id}" -a -f "${ZWE_zowe_workspaceDirectory}/.env/${component_id}/.instance-${ZWE_CLI_PARAMETER_HA_INSTANCE}.env" ]; then
    source_env "${ZWE_zowe_workspaceDirectory}/.env/${component_id}/.instance-${ZWE_CLI_PARAMETER_HA_INSTANCE}.env"
  else
    source_env "${ZWE_zowe_workspaceDirectory}/.env/.instance-${ZWE_CLI_PARAMETER_HA_INSTANCE}.env"
  fi

  # generate other variables
  export ZWE_INSTALLED_COMPONENTS="$(find_all_installed_components)"
  export ZWE_ENABLED_COMPONENTS="$(find_all_enabled_components)"
  export ZWE_LAUNCH_COMPONENTS="$(find_all_launch_components)"
}
