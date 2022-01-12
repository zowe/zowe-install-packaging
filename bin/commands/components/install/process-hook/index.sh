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

###############################
# Variables
target_dir=$(remove_trailing_slash "${ZWE_CLI_PARAMETER_TARGET_DIR}")

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
