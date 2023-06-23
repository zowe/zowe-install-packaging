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

error_code="${ZWE_CLI_PARAMETER_ERROR_CODE}"

server_code=$(echo "${error_code}" | cut -c4)

if echo $error_code | grep -q -E "^[zZ][wW][eE][AaSsDdLl][A-Za-z]?[0-9]{3,4}[A-Za-z]$"; then
  if [[ "$server_code" == [Dd] ]]; then
    print_message "This code corresponds to the errors related to the ZOWE Desktop and the App Server."
    print_message "To find the description of this error code, refer to the Zowe documentation at https://github.com/zowe/docs-site/blob/master/docs/troubleshoot/app-framework/appserver-error-codes.md"
  elif [[ "$server_code" == [Ss] ]]; then
    print_message "This code corresponds to the errors related to the Zowe Subsystem Services (ZSS) and Zowe Installation Services (ZIS)"
    print_message "To find the description of this error code, refer to the Zowe documentation for ZSS at https://docs.zowe.org/stable/troubleshoot/app-framework/zss-error-codes and for ZIS at https://github.com/zowe/docs-site/blob/master/docs/troubleshoot/app-framework/zis-error-codes.md"
    print_message "You may also explore reports from other users experiencing the same error by searching here https://github.com/search?q=org%3Azowe+${error_code}&type=discussions"
  elif [[ "$server_code" == [Aa] ]]; then
    print_message "This code corresponds to the errors related to the Zowe API Mediation Layer (APIML)."
    print_message "To find the description of this error code, refer to the Zowe documentation at https://docs.zowe.org/stable/troubleshoot/troubleshoot-apiml-error-codes"
  elif [[ "$server_code" == [Ll] ]]; then
    print_message "This code corresponds to the errors related to the Zowe Launcher and ZWE"
    print_message "To find the description of this error code, refer to the Zowe documentation for the Launcher at https://docs.zowe.org/stable/troubleshoot/launcher/launcher-error-codes and https://github.com/zowe/launcher/blob/v2.x/master/src/msg.h, and for ZWE at https://docs.zowe.org/stable/appendix/zwe_server_command_reference/zwe/ "
  fi
else
  print_error_and_exit "Invalid Error Code" "" 102
fi
