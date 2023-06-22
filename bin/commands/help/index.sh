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


print_level1_message "Here is the message: ${ZWE_CLI_PARAMETER_ERROR_CODE}"
error_code="${ZWE_CLI_PARAMETER_ERROR_CODE}"

server_code=${error_code:3:1}

if [[ "$server_code" == [Dd] ]]; then
  print_message "The code corresponds to the errors related to the ZOWE Desktop and the App Server."
  print_message "For more information, please refer to the Zowe documentation on App Server Return Codes at https://docs.zowe.org/stable/troubleshoot/app-framework/app-return-codes"
elif [[ "$server_code" == [Ss] ]]; then
  print_message "The code corresponds to the errors related to the Zowe Subsystem Services (ZSS)"
  print_message "You can find a description of this error code in the Zowe documentation at https://docs.zowe.org/stable/troubleshoot/app-framework/zss-error-codes"
  print_message "You may also explore reports from other users experiencing the same error by searching here https://github.com/search?q=org%3Azowe+${messageId}&type=issues"
elif [[ "$server_code" == [Aa] ]]; then
  print_message "The code corresponds to the errors related to the Zowe API Mediation Layer (APIML)."
  print_message "You can find a description of this error code in the Zowe documentation at https://docs.zowe.org/stable/troubleshoot/troubleshoot-apiml-error-codes"
else
  print_error_and_exit "Invalid Error Code" "" 102
fi

