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

require_node
require_zowe_yaml

component_dir=$(find_component_directory "${ZWE_CLI_PARAMETER_COMPONENT_NAME}")
if [ -z "${component_dir}" ]; then
  print_error_and_exit "Error ZWEL0152E: Cannot find component ${ZWE_CLI_PARAMETER_COMPONENT_NAME}." "" 152
fi
componentCfgPath=
if [ -n "${ZWE_CLI_PARAMETER_HA_INSTANCE}" ]; then
  componentCfgPath="haInstances.${ZWE_CLI_PARAMETER_HA_INSTANCE}.components.${ZWE_CLI_PARAMETER_COMPONENT_NAME}"
else
  componentCfgPath="components.${ZWE_CLI_PARAMETER_COMPONENT_NAME}"
fi
update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "${componentCfgPath}.enabled" "false"
