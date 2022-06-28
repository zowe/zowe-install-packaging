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

USE_CONFIGMGR=${ZWE_CLI_PARAMETER_CONFIGMGR}
if [ -n "${ZWE_CLI_PARAMETER_CONFIG}" -a "${USE_CONFIGMGR}" != "true" ]; then
  USE_CONFIGMGR=$(shell_read_yaml_config "${ZWE_CLI_PARAMETER_CONFIG}" 'zowe' 'useConfigmgr')
fi
if [ "${USE_CONFIGMGR}" = "true" ]; then
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/internal/get-launch-components/cli.js"
else


###############################
# validation
require_zowe_yaml

###############################
load_environment_variables

echo "${ZWE_LAUNCH_COMPONENTS}"

fi
