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

echo "I'm the init command"
echo

echo "-----------------"
echo "Parameters passed:"
for param in ${ZWECLI_PARAMETERS_LIST}; do
  echo "- ${param}: $(zwecli_get_parameter_value "${param}")"
done
echo

echo "-----------------"
if [ -z "${ZWECLI_PARAMETER_CONFIG}" ]; then
  >&2 echo "Error: config file is required."
  exit 1
elif [ ! -f "${ZWECLI_PARAMETER_CONFIG}" ]; then
  >&2 echo "Error: config file does not exist."
  exit 1
else
  echo "Content of ${ZWECLI_PARAMETER_CONFIG}"
  cat "${ZWECLI_PARAMETER_CONFIG}"
fi
