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
# validation
require_zowe_yaml

# check and sanitize ZWE_CLI_PARAMETER_HA_INSTANCE
sanitize_ha_instance_id

ZWE_zowe_workspaceDirectory=$(read_yaml ${ZWE_CLI_PARAMETER_CONFIG} '.zowe.workspaceDirectory')
if [ -z "${ZWE_zowe_workspaceDirectory}" -o "${ZWE_zowe_workspaceDirectory}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe workspace directory (zowe.workspaceDirectory) is not defined in Zowe YAML configuration file." "" 157
fi

###############################
load_environment_variables

echo "${ZWE_LAUNCH_COMPONENTS}"
