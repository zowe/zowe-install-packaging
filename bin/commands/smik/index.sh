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
error_code=${ZWE_CLI_PARAMETER_ERROR_CODE}

echo "Error Code: $error_code"

if [ "$error_code" =~ ^[zZ][wW][eE][AaSsDdLl][A-Za-z]?[0-9]{3,4}[A-Za-z]$ ]; then
  echo "Valid error id"
else
  echo "INvalid error id"
fi

