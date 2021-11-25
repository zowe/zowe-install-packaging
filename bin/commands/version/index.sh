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

if [ -f "${ZWE_zowe_runtimeDirectory}/manifest.json" ]; then
  manifest="${ZWE_zowe_runtimeDirectory}/manifest.json"
elif [ -f "${ZWE_zowe_runtimeDirectory}/manifest.json.template" ]; then
  manifest="${ZWE_zowe_runtimeDirectory}/manifest.json.template"
else
  print_error_and_exit "Error ZWEI0150E: Failed to find Zowe manifest.json. Zowe runtimeDirectory is invalid." "" 150
fi

ZOWE_VERSION=$(shell_read_json_config "${manifest}" version version)
# $(shell_read_json_config ${ROOT_DIR}/manifest.json 'version' 'version')
print_message "Zowe v${ZOWE_VERSION}"
print_debug "build and hash: $(shell_read_json_config "${manifest}" 'build' 'branch')#$(shell_read_json_config "${manifest}" 'build' 'number') ($(shell_read_json_config "${manifest}" 'build' 'commitHash'))"
print_trace "Zowe directory: ${ZWE_zowe_runtimeDirectory}"
