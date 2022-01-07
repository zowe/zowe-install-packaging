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

print_level1_message "Verify certificate of \"${ZWE_CLI_PARAMETER_HOST}:${ZWE_CLI_PARAMETER_PORT}\""

validate_certificate_domain "${ZWE_CLI_PARAMETER_HOST}" "${ZWE_CLI_PARAMETER_PORT}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWEL0171E: Failed to verify certificate (CN and SAN) of \"${ZWE_CLI_PARAMETER_HOST}:${ZWE_CLI_PARAMETER_PORT}\"." "" 171
fi

print_level2_message "Certificate of \"${ZWE_CLI_PARAMETER_HOST}:${ZWE_CLI_PARAMETER_PORT}\" is valid."
