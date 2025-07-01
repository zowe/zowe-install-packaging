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

CEE_RO="XPLINK(ON),HEAPPOOLS(OFF),HEAPPOOLS64(OFF)"

if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then
  # user-facing command, use tmpdir to not mess up workspace permissions
  export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=1
fi
if [ -n "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
  _CEE_RUNOPTS="${CEE_RO}" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/install/cli.js"
  exit $?
else
  print_error_and_exit "Error ZWEL0108E: Zowe YAML config file is required." "" 108
fi
