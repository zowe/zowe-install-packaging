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

echo "Error Code: $error_code"
server_code=$(echo "${error_code}" | cut -c4)
echo "Server Code: $server_code"

case $error_code in
  [zZ][wW][eE][AaSsDdLl][A-Za-z]?[0-9]{3,4}[A-Za-z])
    case $server_code in
      [Dd])
        echo "Valid code"
        ;;
    esac
    ;;
esac


