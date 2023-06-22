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


print_level1_message "Here is the message: ${ZWE_CLI_PARAMETER_MESSAGEID}"
error_code="${ZWE_CLI_PARAMETER_MESSAGEID}"

echo "Error Code: $error_code"
server_code=${error_code:3:1}
echo "Server Code: $server_code"
