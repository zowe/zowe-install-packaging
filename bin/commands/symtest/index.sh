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

exm_file="${ZWE_CLI_PARAMETER_ERROR_CODE}"
echo "file_name: ${exm_file}"

# Create a new file in the workspace directory
filepath="${ZWE_CLI_PARAMETER_ERROR_CODE}/result.txt"

# Write the output of `pwd` and the message to the file
pwd > "$filepath"
echo "We have successfully written the content of the pwd: $(pwd) to this file" >> "$filepath"

echo "File created: $filepath"


