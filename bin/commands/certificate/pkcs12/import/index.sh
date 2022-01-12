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

updated=false

# import certificate
if [ -n "${ZWE_CLI_PARAMETER_SOURCE_KEYSTORE}" -a -n "${ZWE_CLI_PARAMETER_SOURCE_PASSWORD}" -a -n "${ZWE_CLI_PARAMETER_SOURCE_ALIAS}" ]; then
  print_level1_message "Import certificate into keystore ${ZWE_CLI_PARAMETER_KEYSTORE}"

  pkcs12_import_pkcs12_keystore \
    "${ZWE_CLI_PARAMETER_KEYSTORE}" \
    "${ZWE_CLI_PARAMETER_PASSWORD}" \
    "${ZWE_CLI_PARAMETER_ALIAS}" \
    "${ZWE_CLI_PARAMETER_SOURCE_KEYSTORE}" \
    "${ZWE_CLI_PARAMETER_SOURCE_PASSWORD}" \
    "${ZWE_CLI_PARAMETER_SOURCE_ALIAS}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0179E: Failed to import certificate into keystore ${ZWE_CLI_PARAMETER_KEYSTORE}." "" 179
  fi

  print_level2_message "Certificate is imported successfully."
  updated=true
fi

# import certificate authorities
if [ -n "${ZWE_CLI_PARAMETER_TRUST_CAS}" ]; then
  print_level1_message "Import certificate authorities into keystore ${ZWE_CLI_PARAMETER_KEYSTORE}"

  pkcs12_import_certificates \
    "${ZWE_CLI_PARAMETER_KEYSTORE}" \
    "${ZWE_CLI_PARAMETER_PASSWORD}" \
    "${ZWE_CLI_PARAMETER_TRUST_CAS}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0179E: Failed to import certificate authorities into keystore ${ZWE_CLI_PARAMETER_KEYSTORE}." "" 179
  fi

  print_level2_message "Certificate authorities are imported successfully."
  updated=true
fi

if [ "${updated}" != "true" ]; then
  print_message "WARNING: No certificates were imported into keystore ${ZWE_CLI_PARAMETER_KEYSTORE}."
fi
