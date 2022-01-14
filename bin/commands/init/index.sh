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

print_level0_message "Configure Zowe"

###############################
# detect and write node/java home
if [ "${ZWE_CLI_PARAMETER_UPDATE_CONFIG}" = "true" ]; then
  print_level1_message "Check if we need to update runtime directory, Java and/or node.js settings in Zowe YAML configuration"
  yaml_updated=

  yaml_node_home="$(shell_read_yaml_node_home "${ZWE_CLI_PARAMETER_CONFIG}")"
  # only try to update if it's not defined
  if [ -z "${yaml_node_home}" ]; then
    require_node
    if [ -n "${NODE_HOME}" ]; then
      update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "node.home" "${NODE_HOME}"
      yaml_updated=true
    fi
  fi

  yaml_java_home="$(shell_read_yaml_java_home "${ZWE_CLI_PARAMETER_CONFIG}")"
  # only try to update if it's not defined
  if [ -z "${yaml_java_home}" ]; then
    require_java
    if [ -n "${JAVA_HOME}" ]; then
      update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "java.home" "${JAVA_HOME}"
      yaml_updated=true
    fi
  fi

  require_zowe_yaml

  # do we have zowe.runtimeDirectory defined in zowe.yaml?
  yaml_runtime_dir=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.runtimeDirectory")
  if [ -n "${yaml_runtime_dir}" ]; then
    result=$(are_directories_same "${yaml_runtime_dir}" "${ZWE_zowe_runtimeDirectory}")
    code=$?
    if [ ${code} -ne 0 ]; then
      print_error_and_exit "Error ZWEL0105E: The Zowe YAML config file is associated to Zowe runtime \"${yaml_runtime_dir}\", which is not same as where zwe command is located." "" 105
    fi
    # no need to update
  else
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.runtimeDirectory" "${ZWE_zowe_runtimeDirectory}"
    yaml_updated=true
  fi

  if [ "${yaml_updated}" = "true" ]; then
    print_level2_message "Runtime directory, Java and/or node.js settings are updated successfully."
  else
    print_level2_message "Runtime directory, Java and node.js settings are not updated."
  fi
fi

###############################
zwecli_inline_execute_command init mvs
zwecli_inline_execute_command init vsam
if [ "${ZWE_CLI_PARAMETER_SKIP_SECURITY_SETUP}" != "true" ]; then
  zwecli_inline_execute_command init apfauth
  zwecli_inline_execute_command init security
fi
zwecli_inline_execute_command init certificate
zwecli_inline_execute_command init stc

print_level1_message "Zowe is configured successfully."
