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

print_level1_message "Creating certificate authority \"${ZWE_CLI_PARAMETER_ALIAS}\""

# check existence
keystore="${ZWE_CLI_PARAMETER_KEYSTORE_DIR}/${ZWE_CLI_PARAMETER_ALIAS}/${ZWE_CLI_PARAMETER_ALIAS}.keystore.p12"
if [ -f "${keystore}" ]; then
  if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
    # warning
    print_message "Warning ZWEL0300W: Keystore \"${keystore}\" already exists. This keystore will be overwritten during configuration."
    rm -fr "${ZWE_CLI_PARAMETER_KEYSTORE_DIR}/${ZWE_CLI_PARAMETER_ALIAS}"
  else
    # error
    print_error_and_exit "Error ZWEL0158E: Keystore \"${keystore}\" already exists." "" 158
  fi
fi

# create CA
ZWE_PRIVATE_CERTIFICATE_CA_ORG_UNIT="${ZWE_CLI_PARAMETER_ORG_UNIT}" \
  ZWE_PRIVATE_CERTIFICATE_CA_ORG="${ZWE_CLI_PARAMETER_ORG}" \
  ZWE_PRIVATE_CERTIFICATE_CA_LOCALITY="${ZWE_CLI_PARAMETER_LOCALITY}" \
  ZWE_PRIVATE_CERTIFICATE_CA_STATE="${ZWE_CLI_PARAMETER_STATE}" \
  ZWE_PRIVATE_CERTIFICATE_CA_COUNTRY="${ZWE_CLI_PARAMETER_COUNTRY}" \
  ZWE_PRIVATE_CERTIFICATE_CA_VALIDITY="${ZWE_CLI_PARAMETER_VALIDITY}" \
  pkcs12_create_certificate_authority \
  "${ZWE_CLI_PARAMETER_KEYSTORE_DIR}" \
  "${ZWE_CLI_PARAMETER_ALIAS}" \
  "${ZWE_CLI_PARAMETER_PASSWORD}" \
  "${ZWE_CLI_PARAMETER_COMMON_NAME}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWEL0168E: Failed to create certificate authority \"${ZWE_CLI_PARAMETER_ALIAS}\"." "" 168
fi

print_level2_message "Certificate authority ${ZWE_CLI_PARAMETER_ALIAS} is created successfully."
