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

print_level1_message "Trust ${ZWE_CLI_PARAMETER_SERVICE_NAME} \"${ZWE_CLI_PARAMETER_HOST}:${ZWE_CLI_PARAMETER_PORT}\""

# check existence
truststore="${ZWE_CLI_PARAMETER_KEYSTORE_DIR}/${ZWE_CLI_PARAMETER_KEYSTORE}/${ZWE_CLI_PARAMETER_KEYSTORE}.truststore.p12"
if [ ! -f "${truststore}" ]; then
  print_error_and_exit "Error ZWEL0158E: Truststore \"${truststore}\" does not exists." "" 158
fi

# import certificate
pkcs12_trust_service \
  "${ZWE_CLI_PARAMETER_KEYSTORE_DIR}" \
  "${ZWE_CLI_PARAMETER_KEYSTORE}" \
  "${ZWE_CLI_PARAMETER_PASSWORD}" \
  "${ZWE_CLI_PARAMETER_HOST}" \
  "${ZWE_CLI_PARAMETER_PORT}" \
  "${ZWE_CLI_PARAMETER_ALIAS}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWEL0170E: Failed to trust ${ZWE_CLI_PARAMETER_SERVICE_NAME} \"${ZWE_CLI_PARAMETER_HOST}:${ZWE_CLI_PARAMETER_PORT}\"." "" 170
fi

if [ "${ZWE_CLI_PARAMETER_VERIFY}" = "true" ]; then
  validate_certificate_domain "${ZWE_CLI_PARAMETER_HOST}" "${ZWE_CLI_PARAMETER_PORT}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0171E: Failed to verify certificate (CN and SAN) of ${ZWE_CLI_PARAMETER_SERVICE_NAME} \"${ZWE_CLI_PARAMETER_HOST}:${ZWE_CLI_PARAMETER_PORT}\"." "" 171
  fi
fi

print_level2_debug "Certificate ${ZWE_CLI_PARAMETER_ALIAS} is created successfully."
