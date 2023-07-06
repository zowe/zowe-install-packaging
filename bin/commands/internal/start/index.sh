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
  echo "-----EXECUTING THIS FROM THE INDEX.SH FILE WHILE STARTING ZOWE"
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/internal/start/cli.js"
else
  echo "-----HI THERE EXECUTING THIS FROM THE INDEX.SH FILE WHILE STARTING ZOWE"

###############################
# validation
require_zowe_yaml

###############################
# prepare instance/.env and instance/workspace directories
zwecli_inline_execute_command internal start prepare

###############################
# start component(s)
if [ -n "${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}" ]; then
  # we only start one component in container
  zwecli_inline_execute_command internal start component --component "${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}" &
  # explicit wait is required
  wait
else
  # ZWE_LAUNCH_COMPONENTS can also get from stdout of "zwe internal get-launch-components"
  for run_zowe_start_component_id in $(echo "${ZWE_LAUNCH_COMPONENTS}" | sed "s/,/ /g"); do
    # only run in background when it's not in container, on z/OS
    zwecli_inline_execute_command internal start component --component "${run_zowe_start_component_id}" --run-in-background
  done
fi

fi

file_path="${ZWE_zowe_runtimeDirectory}/workspace/filenm.txt"
echo "File: $file_path"
pwd > "$file_path"
echo "We have successfully written the content of the pwd: $(pwd) to this file" >> "$file_path"

file_path_new="${ZWE_zowe_runtimeDirectory}/workspace/filenew.txt"
echo "File: $file_path_new"
resolved_path=$(cd "$(dirname "$ZWE_zowe_runtimeDirectory")/extensions"; pwd)
echo "$resolved_path" > "$file_path_new"
echo "We have successfully written the content of the pwd: $(pwd) to this file" >> "$file_path_new"
