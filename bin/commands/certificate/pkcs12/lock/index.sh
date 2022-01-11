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

print_level1_message "Lock keystore directory ${ZWE_CLI_PARAMETER_KEYSTORE_DIR}"

# lock keystore directory with proper permission
pkcs12_lock_keystore_directory \
  "${ZWE_CLI_PARAMETER_KEYSTORE_DIR}" \
  "${ZWE_CLI_PARAMETER_USER}" \
  "${ZWE_CLI_PARAMETER_GROUP}" \
  "${ZWE_CLI_PARAMETER_GROUP_PERMISSION}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWEL0177E: Failed to lock keystore directory ${ZWE_CLI_PARAMETER_KEYSTORE_DIR}." "" 177
fi

print_level2_message "Keystore directory ${ZWE_CLI_PARAMETER_KEYSTORE_DIR} is locked successfully."
