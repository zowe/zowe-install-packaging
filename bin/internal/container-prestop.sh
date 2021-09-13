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

#######################################################################
# Prepare runtime directory when Zowe is running in containers

# exit if there are errors
set -e

#######################################################################
# Constants
SOURCE_DIR=/component
RUNTIME_DIR=/home/zowe/runtime
INSTANCE_DIR=/home/zowe/instance
WORKSPACE_DIR=${INSTANCE_DIR}/workspace
STATIC_DEF_CONFIG_DIR=${WORKSPACE_DIR}/api-mediation/api-defs
POD_NAME=$(hostname -s 2>/dev/null)

#######################################################################
echo ">>> delete static definitions written by current pod ${POD_NAME}"
if [ -d "${STATIC_DEF_CONFIG_DIR}" -a -n "${POD_NAME}" ]; then
  ZWELS_HA_INSTANCE_ID=$(echo "${POD_NAME}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/_/g')
  echo "    - listing ${STATIC_DEF_CONFIG_DIR}"
  cd "${STATIC_DEF_CONFIG_DIR}"
  ls -l *.${ZWELS_HA_INSTANCE_ID}.* || true
  echo "    - deleting"
  rm -f *.${ZWELS_HA_INSTANCE_ID}.*
fi

#######################################################################
echo ">>> done"
