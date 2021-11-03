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
for param in ${ZSCLI_PARAMETERS_LIST}; do
  echo "- ${param}: $(zscli_get_parameter "${param}")"
done
echo

echo "-----------------"
if [ -z "${ZSCLI_PARAMETER_CONFIG}" ]; then
  >&2 echo "Error: config file is required."
  exit 1
elif [ ! -f "${ZSCLI_PARAMETER_CONFIG}" ]; then
  >&2 echo "Error: config file does not exist."
  exit 1
else
  echo "Content of ${ZSCLI_PARAMETER_CONFIG}"
  cat "${ZSCLI_PARAMETER_CONFIG}"
fi
