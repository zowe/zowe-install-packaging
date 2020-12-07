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
# Read component manifest
#
# Note: this function requires Java, which means JAVA_HOME should have been defined,
#       and ensure_java_is_on_path should have been executed.
#
# Required environment variables:
# - ROOT_DIR
# - JAVA_HOME
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
    return 0
  fi
  # java should have already been put into PATH

  utils_dir="${ROOT_DIR}/bin/utils"
  fconv="${utils_dir}/format-converter-cli.jar"
  jq="${utils_dir}/jackson-jq-cli.jar"

  if [ -f "${component_dir}/manifest.yaml" ]; then
    java -jar "${fconv}" "${component_dir}/manifest.yaml" | java -jar "${jq}" -r "${manifest_key}"
  elif [ -f "${component_dir}/manifest.yml" ]; then
    java -jar "${fconv}" "${component_dir}/manifest.yml" | java -jar "${jq}" -r "${manifest_key}"
  elif [ -f "${component_dir}/manifest.json" ]; then
    cat "${component_dir}/manifest.json" | java -jar "${jq}" -r "${manifest_key}"
  fi

  return 0
}
