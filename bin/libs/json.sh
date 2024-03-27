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

# If node.home, java.home, or zowe.runtimeDirectory are missing,
# And if the user desires, we can attempt to update the zowe.yaml
# With the paths we discover.
init_missing_yaml_properties() {
  # Check if we can update node/java home, or runtime dir.
  # Only possible right now if the config is a basic file.
  # no FILE() or PARMLIB() syntax can be handled here yet.
  if [ -e "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
    update_node_home=
    found_node_home="$(shell_read_yaml_node_home "${ZWE_CLI_PARAMETER_CONFIG}")"
    # only try to update if it's not defined
    if [ -z "${found_node_home}" ]; then
      update_node_home=$(detect_node_home)
    fi

    update_java_home=
    found_java_home="$(shell_read_yaml_java_home "${ZWE_CLI_PARAMETER_CONFIG}")"
    # only try to update if it's not defined
    if [ -z "${found_java_home}" ]; then
      update_java_home=$(detect_java_home)
    fi

    update_zowe_runtime_dir=
    # do we have zowe.runtimeDirectory defined in zowe.yaml?
    yaml_runtime_dir=$(shell_read_yaml_config "${ZWE_CLI_PARAMETER_CONFIG}" "zowe" "runtimeDirectory")
    if [ -z "${yaml_runtime_dir}" ]; then
      update_zowe_runtime_dir="${ZWE_zowe_runtimeDirectory}"
    fi

    if [ -n "${update_node_home}" -o -n "${update_java_home}" -o -n "${update_zowe_runtime_dir}" ]; then
      if [ "${ZWE_CLI_PARAMETER_UPDATE_CONFIG}" = "true" ]; then
        if [ -n "${update_node_home}" ]; then
          update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "node.home" "${update_node_home}"
        fi
        if [ -n "${update_java_home}" ]; then
          update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "java.home" "${update_java_home}"
        fi
        if [ -n "${update_zowe_runtime_dir}" ]; then
          update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.runtimeDirectory" "${update_zowe_runtime_dir}"
        fi

        print_level2_message "Runtime directory, Java and/or node.js settings are updated successfully."
      else
        print_message "These configurations need to be added to your YAML configuration file:"
        print_message ""
        if [ -n "${update_zowe_runtime_dir}" ]; then
          print_message "zowe:"
          print_message "  runtimeDirectory: \"${update_zowe_runtime_dir}\""
        fi
        if [ -n "${update_node_home}" ]; then
          print_message "node:"
          print_message "  home: \"${update_node_home}\""
        fi
        if [ -n "${update_java_home}" ]; then
          print_message "java:"
          print_message "  home: \"${update_java_home}\""
        fi

        print_level2_message "Please manually update \"${ZWE_CLI_PARAMETER_CONFIG}\" before you start Zowe."
      fi
    fi
  fi
}



###############################
# Read JSON configuration from shell script
#
# Note: this is not a reliable way to read JSON file. The JSON file must be
#       properly formatted, each key/value pair takes one line.
#
# FIXME: we should have a language neutral JSON reading tool, not using shell script.
#
# @param string   JSON file name
# @param string   parent key to read after
# @param string   which key to read
# @param string   if this variable is required. If this is true and we cannot
#                 find the value of the key, an error will be displayed.
shell_read_json_config() {
  json_file="${1}"
  parent_key="${2}"
  key="${3}"
  required="${4}"

  val=$(cat "${json_file}" | awk "/\"${parent_key}\":/{x=NR+200}(NR<=x){print}" | grep "\"${key}\":" | head -n 1 | awk -F: '{print $2;}' | tr -d '[[:space:]]' | sed -e 's/,$//' | sed -e 's/^"//' -e 's/"$//')
  if [ -z "${val}" ]; then
    if [ "${required}" = "true" ]; then
      print_error_and_exit "Error ZWEL0131E: Cannot find key ${parent_key}.${key} defined in file ${json_file}." "" 131
    fi
  else
    printf "${val}"
  fi
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
  yaml_file="${1}"
  parent_key="${2}"
  key="${3}"
  required="${4}"

  val=$(cat "${yaml_file}" | awk "/^ *${parent_key}:/{x=NR+2000;next}(NR<=x){print}" | grep -e "^ \+${key}:" | head -n 1 | awk -F: '{print $2;}' | tr -d '[[:space:]]' | sed -e 's/^"//' -e 's/"$//')
  if [ -z "${val}" ]; then
    if [ "${required}" = "true" ]; then
      print_error_and_exit "Error ZWEL0131E: Cannot find key ${parent_key}.${key} defined in file ${yaml_file}." "" 131
    fi
  else
    printf "${val}"
  fi
}

read_yaml() {
  file="${1}"
  key="${2}"
  ignore_null="${3:-true}"

  utils_dir="${ZWE_zowe_runtimeDirectory}/bin/utils"
  fconv="${utils_dir}/fconv/src/index.js"
  jq="${utils_dir}/njq/src/index.js"

  print_trace "- read_yaml load content from ${file}"
  ZWE_PRIVATE_YAML_CACHE=$(node "${fconv}" --input-format=yaml "${file}" 2>&1)
  code=$?
  print_trace "  * Exit code: ${code}"
  if [ ${code} -ne 0 ]; then
    print_error "  * Output:"
    print_error "$(padding_left "${ZWE_PRIVATE_YAML_CACHE}" "    ")"
    return ${code}
  fi

  print_trace "- read_yaml ${key} from yaml content"
  result=$(echo "${ZWE_PRIVATE_YAML_CACHE}" | node "${jq}" -r "${key}" 2>&1)
  code=$?
  print_trace "  * Exit code: ${code}"
  print_trace "  * Output:"
  if [ -n "${result}" ]; then
    print_trace "$(padding_left "${result}" "    ")"
  fi

  if [ ${code} -eq 0 ]; then
    if [ "${ignore_null}" = "true" ]; then
      if [ "${result}" = "null" -o "${result}" = "undefined" ]; then
        result=
      fi
    fi
    printf "${result}"
  fi

  return ${code}
}

read_json() {
  file="${1}"
  key="${2}"
  ignore_null="${3:-true}"

  utils_dir="${ZWE_zowe_runtimeDirectory}/bin/utils"
  jq="${utils_dir}/njq/src/index.js"

  print_trace "- read_json ${key} from ${file}"
  result=$(cat "${file}" | node "${jq}" -r "${key}" 2>&1)
  code=$?
  print_trace "  * Exit code: ${code}"
  print_trace "  * Output:"
  if [ -n "${result}" ]; then
    print_trace "$(padding_left "${result}" "    ")"
  fi

  if [ ${code} -eq 0 ]; then
    if [ "${ignore_null}" = "true" -a "${result}" = "null" ]; then
      result=
    fi
    printf "${result}"
  fi

  return ${code}
}

read_json_string() {	
  string="${1}"	
  key="${2}"	
  ignore_null="${3:-true}"	
  utils_dir="${ZWE_zowe_runtimeDirectory}/bin/utils"	
  jq="${utils_dir}/njq/src/index.js"	
  result=$(echo "${string}" | node "${jq}" -r "${key}" 2>&1)	
  code=$?	
  print_trace "  * Exit code: ${code}"	
  print_trace "  * Output:"	
  if [ -n "${result}" ]; then	
    print_trace "$(padding_left "${result}" "    ")"	
  fi	
  if [ ${code} -eq 0 ]; then	
    if [ "${ignore_null}" = "true" -a "${result}" = "null" ]; then	
      result=	
    fi	
    printf "${result}"	
  fi	
  return ${code}	
}

update_yaml() {
  file="${1}"
  key="${2}"
  val="${3}"
  expected_sample="${4}"

  utils_dir="${ZWE_zowe_runtimeDirectory}/bin/utils"
  config_converter="${utils_dir}/config-converter/src/cli.js"
  
  print_message "- update \"${key}\" with value: ${val}"
  result=$(node "${config_converter}" yaml update "${file}" "${key}" "${val}")
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
    print_error_and_exit "Error ZWEL0138E: Failed to update key ${key} of file ${file}." "" 138
  fi

  ensure_file_encoding "${file}" "${expected_sample}"
}

update_zowe_yaml() {
  update_yaml "${1}" "${2}" "${3}" "zowe:"
}

delete_yaml() {
  file="${1}"
  key="${2}"
  expected_sample="${3}"

  utils_dir="${ZWE_zowe_runtimeDirectory}/bin/utils"
  config_converter="${utils_dir}/config-converter/src/cli.js"

  print_message "- delete \"${key}\""
  result=$(node "${config_converter}" yaml delete "${file}" "${key}")
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
    print_error_and_exit "Error ZWEL0138E: Failed to delete key ${key} of file ${file}." "" 138
  fi

  ensure_file_encoding "${file}" "${expected_sample}"
}

delete_zowe_yaml() {
  delete_yaml "${1}" "${2}" "zowe:"
}
