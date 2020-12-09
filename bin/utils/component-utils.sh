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

###############################
# Find component root directory
#
# Required environment variables:
# - ROOT_DIR
#
# Optional environment variables:
# - ZWE_EXTENSION_DIR
#
# This function will find the component in this sequence:
#   - check if component id paramter is a path to lifecycle scripts directory
#   - ${ROOT_DIR}/components/<component-id>
#   - ${ZWE_EXTENSION_DIR}/<component-id>
#
# @param string     component id, or path to component lifecycle scripts
# Output            component directory will be written to stdout
find_component_directory() {
  component_id=$1
  # find component lifecycle scripts directory
  component_dir=
  if [ -d "${component_id}" ]; then
    component_lifecycle_dir="${component_id}"
    if [[ ${component_lifecycle_dir} == */bin ]]; then
      # the lifecycle dir ends with /bin, we assume the component root directory is one level up
      component_dir=$(cd ${component_lifecycle_dir}/../;pwd)
    else
      parent_dir=$(cd ${component_lifecycle_dir}/../;pwd)
      if [ -f "${parent_dir}/manifest.yaml" -o -f "${parent_dir}/manifest.yml" -o -f "${parent_dir}/manifest.json" ]; then
        # parent directory has manifest file, we assume it's Zowe component manifest and that's the root folder
        component_dir="${parent_dir}"
      fi
    fi
  else
    if [ -d "${ROOT_DIR}/components/${component_id}" ]; then
      # this is a Zowe build-in component
      component_dir="${ROOT_DIR}/components/${component_id}"
    elif [ -n "${ZWE_EXTENSION_DIR}" ]; then
      if [ -d "${ZWE_EXTENSION_DIR}/${component_id}" ]; then
        # this is an extension installed/linked in ZWE_EXTENSION_DIR
        component_dir="${ZWE_EXTENSION_DIR}/${component_id}"
      fi
    fi
  fi

  echo "${component_dir}"
}

###############################
# Convert component YAML format manifest to JSON and place into workspace foler
#
# Note: this function requires Java, which means JAVA_HOME should have been defined,
#       and ensure_java_is_on_path should have been executed.
#
# Note: this function is for runtime only to prepare workspace
#
# Required environment variables:
# - ROOT_DIR
# - JAVA_HOME
# - WORKSPACE_DIR
#
# Example:
# - convert my-component manifest, a .manifest.json will be created in <WORKSPACE_DIR>/my-component folder
#   convert_component_manifest "/path/to/zowe/components/my-component"
#
# @param string   component directory
convert_component_manifest() {
  component_dir=$1

  if [ -z "$JAVA_HOME" ]; then
    return 1
  fi
  # java should have already been put into PATH

  if [ -z "${WORKSPACE_DIR}" ]; then
    return 1
  fi

  utils_dir="${ROOT_DIR}/bin/utils"
  fconv="${utils_dir}/format-converter-cli.jar"
  component_name=$(basename "${component_dir}")
  component_manifest=

  if [ -f "${component_dir}/manifest.yaml" ]; then
    component_manifest="${component_dir}/manifest.yaml"
  elif [ -f "${component_dir}/manifest.yml" ]; then
    component_manifest="${component_dir}/manifest.yml"
  fi

  if [ -n "${component_manifest}" ]; then
    mkdir -p "${WORKSPACE_DIR}/${component_name}"
    java -jar "${fconv}" -o "${WORKSPACE_DIR}/${component_name}/.manifest.json" "${component_manifest}"
    return $?
  else
    return 1
  fi
}

###############################
# Read component manifest
#
# Note: this function requires Java, which means JAVA_HOME should have been defined,
#       and ensure_java_is_on_path should have been executed.
#
# Required environment variables:
# - ROOT_DIR
# - JAVA_HOME
#
# Optional environment variables:
# - WORKSPACE_DIR
#
# Example:
# - read my-component commands.start value
#   read_component_manifest "/path/to/zowe/components/my-component" ".commands.start"
#
# @param string   component directory
# @param string   string of manifest key. For example: ".commands.configure"
# Output          empty if component doesn't have manifest
#                          , or manifest doesn't have the key
#                          , or JAVA_HOME is not defined
#                 the value defined in the manifest of the selected key
read_component_manifest() {
  component_dir=$1
  manifest_key=$2

  if [ -z "$JAVA_HOME" ]; then
    return 1
  fi
  # java should have already been put into PATH

  utils_dir="${ROOT_DIR}/bin/utils"
  component_name=$(basename "${component_dir}")
  fconv="${utils_dir}/format-converter-cli.jar"
  jq="${utils_dir}/jackson-jq-cli.jar"
  manifest_in_workspace=
  if [ -n "${WORKSPACE_DIR}" ]; then
    manifest_in_workspace="${WORKSPACE_DIR}/${component_name}/.manifest.json"
  fi

  if [ -n "${manifest_in_workspace}" -a -f "${manifest_in_workspace}" ]; then
    cat "${manifest_in_workspace}" | java -jar "${jq}" -r "${manifest_key}"
    return $?
  elif [ -f "${component_dir}/manifest.yaml" ]; then
    java -jar "${fconv}" "${component_dir}/manifest.yaml" | java -jar "${jq}" -r "${manifest_key}"
    return $?
  elif [ -f "${component_dir}/manifest.yml" ]; then
    java -jar "${fconv}" "${component_dir}/manifest.yml" | java -jar "${jq}" -r "${manifest_key}"
    return $?
  elif [ -f "${component_dir}/manifest.json" ]; then
    cat "${component_dir}/manifest.json" | java -jar "${jq}" -r "${manifest_key}"
    return $?
  else
    return 1
  fi
}

###############################
# Parse and process manifest service APIML static definition
#
# The supported manifest entry is ".apimlServices.static[].file". All files defined
# here will be parsed and put into Zowe static definition directory in IBM-850 encoding.
#
# Note: this function requires Java, which means JAVA_HOME should have been defined,
#       and ensure_java_is_on_path should have been executed.
#
# Required environment variables:
# - ROOT_DIR
# - JAVA_HOME
# - STATIC_DEF_CONFIG_DIR
#
# @param string   component directory
process_component_apiml_static_definitions() {
  component_dir=$1

  if [ -z "${STATIC_DEF_CONFIG_DIR}" ]; then
    print_error_message "Error: STATIC_DEF_CONFIG_DIR is required to process component definitions for API Mediation Layer."
    return 1
  fi

  component_name=$(basename "${component_dir}")

  static_defs=$(read_component_manifest "${component_dir}" ".apimlServices.static[].file" 2>/dev/null)
  if [ -z "${static_defs}" -o "${static_defs}" = "null" ]; then
    # does the component define it as object instead of array
    static_defs=$(read_component_manifest "${component_dir}" ".apimlServices.static.file" 2>/dev/null)
  fi

  cd "${component_dir}"
  echo "${static_defs}" | while read one_def; do
    one_def_trimmed=$(echo "${one_def}" | xargs)
    if [ -n "${one_def_trimmed}" -a "${one_def_trimmed}" != "null" ]; then
      print_message "Process component ${component_name} API Mediation Layer static definition ${one_def_trimmed} ..."
      sanitized_def_name=$(echo "${one_def_trimmed}" | sed 's/[^a-zA-Z0-9]/_/g')
      # FIXME: we may change the static definitions files to real template in the future.
      #        currently we support to use environment variables in the static definition template
      cat "${one_def_trimmed}" | envsubst | iconv -f IBM-1047 -t IBM-850 > ${STATIC_DEF_CONFIG_DIR}/${component_name}_${sanitized_def_name}.yml
      chmod 770 ${STATIC_DEF_CONFIG_DIR}/${component_name}_${sanitized_def_name}.yml || true
    fi
  done
}


###############################
# Parse and process manifest desktop iframe plugin definition
#
# The supported manifest entry is ".apimlServices.static[].file". All files defined
# here will be parsed and put into Zowe static definition directory in IBM-850 encoding.
#
# Note: this function requires Java, which means JAVA_HOME should have been defined,
#       and ensure_java_is_on_path should have been executed.
#
# Required environment variables:
# - ROOT_DIR
# - JAVA_HOME
#
# @param string   component directory
process_component_desktop_iframe_plugin() {
  component_dir=$1

  component_name=$(basename "${component_dir}")

  iframe_plugin_defs=$(read_component_manifest "${component_dir}" ".desktopIframePlugins" 2>/dev/null)
  if [ -z "${iframe_plugin_defs}" -o "${iframe_plugin_defs}" = "null" ]; then
    # not defined, exit with 0
    return 0
  fi

  cd "${component_dir}"
  echo "${iframe_plugin_defs}" | while read one_def || [[ -n $one_def ]]; do
    print_message "Process component ${component_name} desktop iframe plugin definition ... [[${one_def}]]"
  done
}

