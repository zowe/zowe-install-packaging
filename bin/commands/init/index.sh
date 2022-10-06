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

USE_CONFIGMGR=$(check_configmgr_enabled)
if [ "${USE_CONFIGMGR}" = "true" ]; then
  if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then

    # user-facing command, use tmpdir to not mess up workspace permissions
    export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=1
  fi
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/init/cli.js"
else


print_level0_message "Configure Zowe"

###############################
print_level1_message "Check if need to update runtime directory, Java and/or node.js settings in Zowe YAML configuration"
# node.home
update_node_home=
yaml_node_home="$(shell_read_yaml_node_home "${ZWE_CLI_PARAMETER_CONFIG}")"
# only try to update if it's not defined
if [ -z "${yaml_node_home}" ]; then
  require_node
  if [ -n "${NODE_HOME}" ]; then
    update_node_home="${NODE_HOME}"
  fi
fi
# java.home
update_java_home=
yaml_java_home="$(shell_read_yaml_java_home "${ZWE_CLI_PARAMETER_CONFIG}")"
# only try to update if it's not defined
if [ -z "${yaml_java_home}" ]; then
  require_java
  if [ -n "${JAVA_HOME}" ]; then
    update_java_home="${JAVA_HOME}"
  fi
fi
# zowe.runtimeDirectory
require_zowe_yaml
update_zowe_runtime_dir=
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
else
  print_level2_message "No need to update runtime directory, Java and node.js settings."
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
fi
