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

server_code=$(echo "${error_code}" | cut -c4)
echo "Server Code: $server_code"

if echo "$error_code" | awk '/^[zZ][wW][eE][AaSsDdLl][A-Za-z]?[0-9]{3,4}[A-Za-z]$/' >/dev/null 2>&1; then
  if [[ "$server_code" == [Dd] ]]; then
    print_message "The code corresponds to the errors related to the ZOWE Desktop and the App Server."
    print_message "For more information, please refer to the Zowe documentation on App Server Return Codes at https://docs.zowe.org/stable/troubleshoot/app-framework/app-return-codes"
  elif [[ "$server_code" == [Ss] ]]; then
    print_message "The code corresponds to the errors related to the Zowe Installation Services (ZIS) and Zowe Subsystem Services (ZSS)"
    print_message "You can find a description of this error code in the Zowe documentation at https://docs.zowe.org/stable/troubleshoot/app-framework/zss-error-codes"
    print_message "You may also explore reports from other users experiencing the same error by searching here https://github.com/search?q=org%3Azowe+${messageId}&type=issues"
  elif [[ "$server_code" == [Aa] ]]; then
    print_message "The code corresponds to the errors related to the Zowe API Mediation Layer (APIML)."
    print_message "You can find a description of this error code in the Zowe documentation at https://docs.zowe.org/stable/troubleshoot/troubleshoot-apiml-error-codes"
  elif [[ "$server_code" == [Ll] ]]; then
    print_message "The code corresponds to the errors related to the Zowe Launcher"
    print_message "You can find a description of this error code in the Zowe documentation at https://docs.zowe.org/stable/troubleshoot/launcher/launcher-error-codes"
  fi
else
  print_error_and_exit "Invalid Error Code" "" 102
fi
