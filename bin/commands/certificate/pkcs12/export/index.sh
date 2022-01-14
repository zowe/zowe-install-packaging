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

print_level1_message "Export keystore ${ZWE_CLI_PARAMETER_KEYSTORE}"

# lock keystore directory with proper permission
pkcs12_export_pem \
  "${ZWE_CLI_PARAMETER_KEYSTORE}" \
  "${ZWE_CLI_PARAMETER_PASSWORD}" \
  "${ZWE_CLI_PARAMETER_PRIVATE_KEYS}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWEL0178E: Failed to export PKCS12 keystore ${ZWE_CLI_PARAMETER_KEYSTORE}." "" 178
fi

print_level2_message "Keystore ${ZWE_CLI_PARAMETER_KEYSTORE} is exported successfully."
