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

print_level1_message "Creating certificate"

# check existence
keystore="${ZWE_CLI_PARAMETER_KEYSTORE_DIR}/${ZWE_CLI_PARAMETER_KEYSTORE}/${ZWE_CLI_PARAMETER_KEYSTORE}.keystore.p12"
if [ -f "${keystore}" ]; then
  if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
    # warning
    print_message "Warning ZWEL0158W: Keystore \"${keystore}\" already exists. This keystore will be overwritten during configuration."
    rm -fr "${ZWE_CLI_PARAMETER_KEYSTORE_DIR}/${ZWE_CLI_PARAMETER_KEYSTORE}"
  else
    # error
    print_error_and_exit "Error ZWEL0158E: Keystore \"${keystore}\" already exists." "" 158
  fi
fi

# create certificate
ZWE_PRIVATE_CERTIFICATE_ORG_UNIT="${ZWE_CLI_PARAMETER_ORG_UNIT}" \
  ZWE_PRIVATE_CERTIFICATE_ORG="${ZWE_CLI_PARAMETER_ORG}" \
  ZWE_PRIVATE_CERTIFICATE_LOCALITY="${ZWE_CLI_PARAMETER_LOCALITY}" \
  ZWE_PRIVATE_CERTIFICATE_STATE="${ZWE_CLI_PARAMETER_STATE}" \
  ZWE_PRIVATE_CERTIFICATE_COUNTRY="${ZWE_CLI_PARAMETER_COUNTRY}" \
  ZWE_PRIVATE_CERTIFICATE_VALIDITY="${ZWE_CLI_PARAMETER_VALIDITY}" \
  ZWE_PRIVATE_CERTIFICATE_KEYUSAGE="${ZWE_CLI_PARAMETER_KEY_USAGE}" \
  ZWE_PRIVATE_CERTIFICATE_EXTENDED_KEYUSAGE="${ZWE_CLI_PARAMETER_EXTENDED_KEY_USAGE}" \
  pkcs12_create_certificate_and_sign \
  "${ZWE_CLI_PARAMETER_KEYSTORE_DIR}" \
  "${ZWE_CLI_PARAMETER_KEYSTORE}" \
  "${ZWE_CLI_PARAMETER_ALIAS}" \
  "${ZWE_CLI_PARAMETER_PASSWORD}" \
  "${ZWE_CLI_PARAMETER_COMMON_NAME}" \
  "${ZWE_CLI_PARAMETER_DOMAINS}" \
  "${ZWE_CLI_PARAMETER_CA_ALIAS}" \
  "${ZWE_CLI_PARAMETER_CA_PASSWORD}"

print_level2_debug "Certificate ${ZWE_CLI_PARAMETER_ALIAS} is created successfully."
