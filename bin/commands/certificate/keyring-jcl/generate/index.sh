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

print_level1_message "Generate Zowe certificate in keyring"

###############################
# constants & variables
job_has_failures=

###############################
# validation

###############################
# run ZWEKRING JCL
ZWE_PRIVATE_CERTIFICATE_CA_ORG_UNIT="${ZWE_CLI_PARAMETER_ORG_UNIT}" \
  ZWE_PRIVATE_CERTIFICATE_CA_ORG="${ZWE_CLI_PARAMETER_ORG}" \
  ZWE_PRIVATE_CERTIFICATE_CA_LOCALITY="${ZWE_CLI_PARAMETER_LOCALITY}" \
  ZWE_PRIVATE_CERTIFICATE_CA_STATE="${ZWE_CLI_PARAMETER_STATE}" \
  ZWE_PRIVATE_CERTIFICATE_CA_COUNTRY="${ZWE_CLI_PARAMETER_COUNTRY}" \
  ZWE_PRIVATE_CERTIFICATE_CA_VALIDITY="${ZWE_CLI_PARAMETER_VALIDITY}" \
  ZWE_PRIVATE_ZOSMF_USER="${ZWE_CLI_PARAMETER_ZOSMF_USER}" \
  keyring_run_zwekring_jcl \
    "${ZWE_CLI_PARAMETER_DATASET_PREFIX}" \
    "${ZWE_CLI_PARAMETER_JCLLIB}" \
    1 \
    "${ZWE_CLI_PARAMETER_KEYRING_OWNER}" \
    "${ZWE_CLI_PARAMETER_KEYRING_NAME}" \
    "${ZWE_CLI_PARAMETER_DOMAINS}" \
    "${ZWE_CLI_PARAMETER_ALIAS}" \
    "${ZWE_CLI_PARAMETER_CA_ALIAS}" \
    "${ZWE_CLI_PARAMETER_TRUST_CAS}" \
    "${ZWE_CLI_PARAMETER_TRUST_ZOSMF}" \
    "${ZWE_CLI_PARAMETER_ZOSMF_CA}" \
    "" \
    "" \
    "" \
    "" \
    "${ZWE_CLI_PARAMETER_VALIDITY}" \
    "${ZWE_CLI_PARAMETER_SECURITY_PRODUCT}"
if [ $? -ne 0 ]; then
  job_has_failures=true
  if [ "${ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES}" = "true" ]; then
    print_error "Error ZWEL0174E: Failed to generate certificate in Zowe keyring \"${ZWE_CLI_PARAMETER_KEYRING_OWNER}/${ZWE_CLI_PARAMETER_KEYRING_NAME}\"."
  else
    print_error_and_exit "Error ZWEL0174E: Failed to generate certificate in Zowe keyring \"${ZWE_CLI_PARAMETER_KEYRING_OWNER}/${ZWE_CLI_PARAMETER_KEYRING_NAME}\"." "" 174
  fi
fi

###############################
# exit message
if [ "${job_has_failures}" = "true" ]; then
  print_level2_message "Failed to generate certificate to Zowe keyring. Please check job log for details."
else
  print_level2_message "Certificate is generated in keyring successfully."
fi
