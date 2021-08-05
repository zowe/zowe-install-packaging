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
EXTENSIONS_DIR=/home/zowe/extensions

#######################################################################
echo ">>> prepare runtime directory"
mkdir -p ${RUNTIME_DIR}
cp -r ${SOURCE_DIR}/. ${RUNTIME_DIR}

#######################################################################
echo ">>> prepare extensions directory"
mkdir -p ${EXTENSIONS_DIR}

#######################################################################
echo ">>> prepare instance directory"
mkdir -p ${INSTANCE_DIR}/bin
mkdir -p ${INSTANCE_DIR}/logs
cp -r ${RUNTIME_DIR}/bin/instance/. ${INSTANCE_DIR}/bin

#######################################################################
echo ">>> check contents of directories"
echo "    - ${RUNTIME_DIR}"
ls -la "${RUNTIME_DIR}"
echo "    - ${INSTANCE_DIR}"
ls -la "${INSTANCE_DIR}"
echo "    - ${EXTENSIONS_DIR}"
ls -la "${EXTENSIONS_DIR}"
