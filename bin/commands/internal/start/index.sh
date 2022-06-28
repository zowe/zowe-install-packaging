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
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/internal/start/cli.js"
else


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
