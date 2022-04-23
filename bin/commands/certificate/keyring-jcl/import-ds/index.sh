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

print_level1_message "Import certificate to Zowe keyring"

###############################
# constants & variables
job_has_failures=

###############################
# validation

###############################
# run ZWEKRING JCL
ZWE_PRIVATE_ZOSMF_USER="${ZWE_CLI_PARAMETER_ZOSMF_USER}" \
  keyring_run_zwekring_jcl \
    "${ZWE_CLI_PARAMETER_DATASET_PREFIX}" \
    "${ZWE_CLI_PARAMETER_JCLLIB}" \
    3 \
    "${ZWE_CLI_PARAMETER_KEYRING_OWNER}" \
    "${ZWE_CLI_PARAMETER_KEYRING_NAME}" \
    "" \
    "${ZWE_CLI_PARAMETER_ALIAS}" \
    "" \
    "${ZWE_CLI_PARAMETER_TRUST_CAS}" \
    "${ZWE_CLI_PARAMETER_TRUST_ZOSMF}" \
    "${ZWE_CLI_PARAMETER_ZOSMF_CA}" \
    "" \
    "" \
    "${ZWE_CLI_PARAMETER_IMPORT_DS_NAME}" \
    "${ZWE_CLI_PARAMETER_IMPORT_DS_PASSWORD}" \
    "" \
    "${ZWE_CLI_PARAMETER_SECURITY_PRODUCT}"
if [ $? -ne 0 ]; then
  job_has_failures=true
  if [ "${ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES}" = "true" ]; then
    print_error "Error ZWEL0173E: Failed to import certificate to Zowe keyring \"${ZWE_CLI_PARAMETER_KEYRING_OWNER}/${ZWE_CLI_PARAMETER_KEYRING_NAME}\"."
  else
    print_error_and_exit "Error ZWEL0173E: Failed to import certificate to Zowe keyring \"${ZWE_CLI_PARAMETER_KEYRING_OWNER}/${ZWE_CLI_PARAMETER_KEYRING_NAME}\"." "" 173
  fi
fi

###############################
# exit message
if [ "${job_has_failures}" = "true" ]; then
  print_level2_message "Failed to import certificate to Zowe keyring. Please check job log for details."
else
  print_level2_message "Certificate is imported to Zowe keyring successfully."
fi
