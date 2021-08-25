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

#######################################################################
echo ">>> before preparation"
echo "  - ${SOURCE_DIR}" && cd "${SOURCE_DIR}" && ls -la
echo "  - /home/zowe" && cd "/home/zowe" && ls -la

#######################################################################
echo ">>> prepare runtime directory"
mkdir -p ${RUNTIME_DIR}/components
cp -r ${SOURCE_DIR}/. ${RUNTIME_DIR}

#######################################################################
echo ">>> prepare instance directory"
# we need to do pretty much same as bin/zowe-configure-instance.sh
mkdir -p ${INSTANCE_DIR}/bin
mkdir -p ${INSTANCE_DIR}/logs
mkdir -p ${INSTANCE_DIR}/tmp
cp -r ${RUNTIME_DIR}/bin/instance/. ${INSTANCE_DIR}/bin
cp ${RUNTIME_DIR}/components/app-server/share/zlux-app-server/bin/install-app.sh ${INSTANCE_DIR}/bin/install-app.sh
# zowe-configure-component.sh will be executed during runtime
touch ${INSTANCE_DIR}/.init-for-container

#######################################################################
echo ">>> after preparation"
echo "  - ${SOURCE_DIR}" && cd "${SOURCE_DIR}" && ls -la
echo "  - /home/zowe" && cd "/home/zowe" && ls -la
echo "  - ${RUNTIME_DIR}" && cd "${RUNTIME_DIR}" && ls -la
echo "  - ${INSTANCE_DIR}" && cd "${INSTANCE_DIR}" && ls -la

#######################################################################
echo ">>> done"
