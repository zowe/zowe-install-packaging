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

print_level1_message "Remove Zowe keyring"

###############################
# constants & variables
job_has_failures=

###############################
# validation

###############################
# run ZWENOKYR JCL
keyring_run_zwenokyr_jcl \
  "${ZWE_CLI_PARAMETER_DATASET_PREFIX}" \
  "${ZWE_CLI_PARAMETER_JCLLIB}" \
  "${ZWE_CLI_PARAMETER_KEYRING_OWNER}" \
  "${ZWE_CLI_PARAMETER_KEYRING_NAME}" \
  "${ZWE_CLI_PARAMETER_ALIAS}" \
  "${ZWE_CLI_PARAMETER_CA_ALIAS}" \
  "${ZWE_CLI_PARAMETER_SECURITY_PRODUCT}"
if [ $? -ne 0 ]; then
  job_has_failures=true
  if [ "${ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES}" = "true" ]; then
    print_error "Error ZWEL0176E: Failed to clean up Zowe keyring \"${ZWE_CLI_PARAMETER_KEYRING_OWNER}/${ZWE_CLI_PARAMETER_KEYRING_NAME}\"."
  else
    print_error_and_exit "Error ZWEL0176E: Failed to clean up Zowe keyring \"${ZWE_CLI_PARAMETER_KEYRING_OWNER}/${ZWE_CLI_PARAMETER_KEYRING_NAME}\"." "" 176
  fi
fi

###############################
# exit message
if [ "${job_has_failures}" = "true" ]; then
  print_level2_message "Failed to remove Zowe keyring. Please check job log for details."
else
  print_level2_message "Zowe keyring is removed successfully."
fi
