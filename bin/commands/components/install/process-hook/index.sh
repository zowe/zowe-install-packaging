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
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/components/install/process-hook/cli.js"
else


require_zowe_yaml

# read extensionDirectory
extensionDir=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.extensionDirectory")
if [ -z "${extensionDir}" ]; then
  print_error_and_exit "Error ZWEL0180E: Zowe extension directory (zowe.extensionDirectory) is not defined in Zowe YAML configuration file." "" 180
fi

###############################
# Variables
target_dir=$(remove_trailing_slash "${extensionDir}")

###############################
# node is required to read module manifest
require_node

commands_install=$(read_component_manifest "${target_dir}/${ZWE_CLI_PARAMETER_COMPONENT_NAME}" ".commands.install" 2>/dev/null)
if [ -n "${commands_install}" ]; then
  print_message "Process ${commands_install} defined in manifest commands.install:"
  cd "${target_dir}/${ZWE_CLI_PARAMETER_COMPONENT_NAME}"
  # run commands
  . ${commands_install}
else
  print_debug "Module ${ZWE_CLI_PARAMETER_COMPONENT_NAME} does not have commands.install defined."
fi

if [ "${ZWE_RUN_ON_ZOS}" = "true" ]; then
  process_zss_plugin_install "${target_dir}/${ZWE_CLI_PARAMETER_COMPONENT_NAME}"
fi

fi
