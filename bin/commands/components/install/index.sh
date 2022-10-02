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
  if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then
    export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=1
  fi
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/components/install/cli.js"
else

zwecli_inline_execute_command components install extract
# ZWE_COMPONENTS_INSTALL_EXTRACT_COMPONENT_NAME should be set after extract step
if [ -n "${ZWE_COMPONENTS_INSTALL_EXTRACT_COMPONENT_NAME}" ]; then
  zwecli_inline_execute_command components install process-hook --component-name "${ZWE_COMPONENTS_INSTALL_EXTRACT_COMPONENT_NAME}"
else
  print_error_and_exit "Error ZWEL0156E: Component name is not initialized after extract step." "" 156
fi
if [ "$ZWE_CLI_PARAMETER_SKIP_ENABLE" != "true" ]; then
  zwecli_inline_execute_command components enable --component-name "${ZWE_COMPONENTS_INSTALL_EXTRACT_COMPONENT_NAME}"
fi

fi
