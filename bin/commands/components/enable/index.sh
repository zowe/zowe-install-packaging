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

require_zowe_yaml

componentCfgPath=
componentCfg=
if [ -z "${ZWE_CLI_PARAMETER_HA_INSTANCE}" ]; then
  componentCfgPath=".haInstances.${ZWE_CLI_PARAMETER_HA_INSTANCE}.components.${ZWE_CLI_PARAMETER_COMPONENT_NAME}"
else
  componentCfgPath=".components.${ZWE_CLI_PARAMETER_COMPONENT_NAME}"
fi
componentCfg=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "${componentCfgPath}"
if [ -z "${componentCfg}" ]; then
  print_error_and_exit "Error ZWEL0156E: Component ${ZWE_CLI_PAREMTER_COMPONENT_NAME} does not exist in zowe.yaml." "" 156 #todo create new error code
fi
update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "${componentCfgPath}.enabled" "true"
