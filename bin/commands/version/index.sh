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

if [ -f "${ZOWE_RUNTIME_DIRECTORY}/manifest.json" ]; then
  manifest="${ZOWE_RUNTIME_DIRECTORY}/manifest.json"
elif [ -f "${ZOWE_RUNTIME_DIRECTORY}/manifest.json.template" ]; then
  manifest="${ZOWE_RUNTIME_DIRECTORY}/manifest.json.template"
else
  >&2 echo "Error: failed to find Zowe manifest.json"
  exit 1
fi

ZOWE_VERSION=$(shell_read_json_config "${manifest}" version version)
# $(shell_read_json_config ${ROOT_DIR}/manifest.json 'version' 'version')
echo "Zowe v${ZOWE_VERSION}"
if [ "${ZSCLI_LOGLEVEL}" = "debug" -o "${ZSCLI_LOGLEVEL}" = "trace" ]; then
  echo "build and hash: $(shell_read_json_config "${manifest}" 'build' 'branch')#$(shell_read_json_config "${manifest}" 'build' 'number') ($(shell_read_json_config "${manifest}" 'build' 'commitHash'))"
fi
if [ "${ZSCLI_LOGLEVEL}" = "trace" ]; then
  echo "Zowe directory: ${ZOWE_RUNTIME_DIRECTORY}"
fi
