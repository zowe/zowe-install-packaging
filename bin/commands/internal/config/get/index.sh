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
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/internal/config/get/cli.js"
else

###############################
# validation
require_zowe_yaml

###############################
if [ -n "${ZWE_CLI_PARAMETER_HA_INSTANCE}" ] && [[ "${ZWE_CLI_PARAMETER_PATH}" != "haInstances.${ZWE_CLI_PARAMETER_HA_INSTANCE}."* ]]; then
  read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".haInstances.${ZWE_CLI_PARAMETER_HA_INSTANCE}.${ZWE_CLI_PARAMETER_PATH}"
else
  read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".${ZWE_CLI_PARAMETER_PATH}"
fi

fi
