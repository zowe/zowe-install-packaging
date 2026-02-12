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

if [ -n "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
  result=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.runtimeDirectory")
  if [ -n "${result}" ]; then
    export ZWE_PRIVATE_COMMANDS_VERSION_ZOWE_RUNTIMEDIRECTORY="${result}"
  fi
fi

_CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF),HEAPPOOLS64(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/version/cli.js"
