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
  print_level1_message "Check if we need to update Java and/or node.js settings in Zowe YAML configuration"
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

  if [ "${yaml_updated}" = "true" ]; then
    print_level2_message "Java and/or node.js settings are updated successfully."
  else
    print_level2_message "Java and node.js settings are not updated."
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
