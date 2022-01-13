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
  yaml_java_home="$(shell_read_yaml_config "${ZWE_CLI_PARAMETER_CONFIG}" 'java' 'home')"
  result=$(validate_java_home "${yaml_java_home}")
  code=$?
  if [ ${code} -ne 0 ]; then
    # incorrect JAVA_HOME, reset and try again
    # this could be caused by failing to read java.home correctly from zowe.yaml
    yaml_java_home=
  fi
  # only try to update if it's not defined
  if [ -z "${yaml_java_home}" ]; then
    java_home_is_empty=
    if [ -z "${JAVA_HOME}" ]; then
      java_home_is_empty=true
    fi
    require_java
    if [ "${java_home_is_empty}" = "true" -a -n "${JAVA_HOME}" ]; then
      update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "java.home" "${JAVA_HOME}"
    fi
  fi

  yaml_node_home="$(shell_read_yaml_config "${ZWE_CLI_PARAMETER_CONFIG}" 'node' 'home')"
  result=$(validate_node_home "${yaml_node_home}")
  code=$?
  if [ ${code} -ne 0 ]; then
    # incorrect JAVA_HOME, reset and try again
    # this could be caused by failing to read node.home correctly from zowe.yaml
    yaml_node_home=
  fi
  # only try to update if it's not defined
  if [ -z "${yaml_node_home}" ]; then
    node_home_is_empty=
    if [ -z "${NODE_HOME}" ]; then
      node_home_is_empty=true
    fi
    require_node
    if [ "${node_home_is_empty}" = "true" -a -n "${NODE_HOME}" ]; then
      update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "node.home" "${NODE_HOME}"
    fi
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
