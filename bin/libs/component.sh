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

get_component_manifest() {
  component_dir=$1

  if [ -f "${component_dir}/manifest.yaml" ]; then
    echo "${component_dir}/manifest.yaml"
  elif [ -f "${component_dir}/manifest.yml" ]; then
    echo "${component_dir}/manifest.yml"
  elif [ -f "${component_dir}/manifest.json" ]; then
    echo "${component_dir}/manifest.json"
  fi
}

###############################
# Read component manifest
#
# Note: this function requires node, which means NODE_HOME should have been defined,
#       and ensure_node_is_on_path should have been executed.
#
# Required environment variables:
# - ROOT_DIR
# - NODE_HOME
#
# Optional environment variables:
# - ZWELS_INSTANCE_ENV_DIR
#
# Example:
# - read my-component commands.start value
#   read_component_manifest "/path/to/zowe/components/my-component" ".commands.start"
#
# @param string   component directory
# @param string   string of manifest key. For example: ".commands.configure"
# Output          empty if component doesn't have manifest
#                          , or manifest doesn't have the key
#                          , or NODE_HOME is not defined
#                 the value defined in the manifest of the selected key
read_component_manifest() {
  component_dir=$1
  manifest_key=$2

  if [ -f "${component_dir}/manifest.yaml" ]; then
    read_yaml "${component_dir}/manifest.yaml" "${manifest_key}"
    return $?
  elif [ -f "${component_dir}/manifest.yml" ]; then
    read_yaml "${component_dir}/manifest.yml" "${manifest_key}"
    return $?
  elif [ -f "${component_dir}/manifest.json" ]; then
    read_json "${component_dir}/manifest.json" "${manifest_key}"
    return $?
  else
    print_error_and_exit "Error ZWEI0132E: No manifest file found in ${component_dir}." "" 132
  fi
}

###############################
# Detect and verify component manifest encoding
#
# Note: this function always returns 0 and if succeeds, it will output encoding
#       to stdout.
#
# Example:
# - detect manifest encoding of my-component
#   detect_component_manifest_encoding "/path/to/zowe/components/my-component"
#
# @param string   component directory
detect_component_manifest_encoding() {
  component_dir=$1

  component_manifest=$(get_component_manifest "${component_dir}")
  if [ -n "${component_manifest}" ]; then
    # manifest at least should have name defined
    confirmed_encoding=$(detect_file_encoding "${component_manifest}" "name")
    if [ -n "${confirmed_encoding}" ]; then
      echo "${confirmed_encoding}"
    fi
  fi
}

detect_if_component_tagged() {
  component_dir=$1

  component_manifest=$(get_component_manifest "${component_dir}")
  if [ -n "${component_manifest}" ]; then
      # manifest at least should have name defined
    tag=$(chtag -p ${component_manifest} | cut -f 2 -d\ )
    if [ ! "${tag}" = "untagged" ]; then
      echo "true"
    else
      echo "false"
    fi
  fi
}
