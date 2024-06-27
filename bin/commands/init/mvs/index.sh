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

init_missing_yaml_properties

if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then
  # user-facing command, use tmpdir to not mess up workspace permissions
  export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=1
fi
_CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF),HEAPPOOLS64(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/init/mvs/cli.js"

