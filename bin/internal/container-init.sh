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
COMPONENT_ROOT_DIR=/component
ROOT_DIR=/home/zowe/runtime
INSTANCE_DIR=/home/zowe/instance
WORKSPACE_DIR=${INSTANCE_DIR}/workspace
PLUGINS_DIR=${WORKSPACE_DIR}/app-server/plugins
STATIC_DEF_CONFIG_DIR=${WORKSPACE_DIR}/api-mediation/api-defs

#######################################################################
echo ">>> before preparation"
echo "  - whoami?" && whoami
echo "  - ${COMPONENT_ROOT_DIR}" && ls -la "${COMPONENT_ROOT_DIR}"
echo "  - /home" && ls -la "/home"
echo "  - /home/zowe" && ls -la "/home/zowe"

#######################################################################
echo ">>> prepare runtime directory"
mkdir -p ${ROOT_DIR}/components
cp -r ${COMPONENT_ROOT_DIR}/. ${ROOT_DIR}

#######################################################################
echo ">>> prepare instance directory"
# we need to do pretty much same as bin/zowe-configure-instance.sh
mkdir -p ${INSTANCE_DIR}/bin
mkdir -p ${INSTANCE_DIR}/logs
mkdir -p ${INSTANCE_DIR}/tmp
cp -r ${ROOT_DIR}/bin/instance/. ${INSTANCE_DIR}/bin
cp ${ROOT_DIR}/components/app-server/share/zlux-app-server/bin/install-app.sh ${INSTANCE_DIR}/bin/install-app.sh
# zowe-configure-component.sh will be executed during runtime
touch ${INSTANCE_DIR}/.init-for-container

#######################################################################
echo ">>> after preparation"
echo "  - ${COMPONENT_ROOT_DIR}" && ls -la "${COMPONENT_ROOT_DIR}"
echo "  - /home/zowe" && ls -la "/home/zowe"
[ -d "${ROOT_DIR}" ] && echo "  - ${ROOT_DIR}" && ls -la "${ROOT_DIR}"
[ -d "${ROOT_DIR}/components" ] && echo "  - ${ROOT_DIR}/components" && ls -la "${ROOT_DIR}/components"
[ -d "${INSTANCE_DIR}" ] && echo "  - ${INSTANCE_DIR}" && ls -la "${INSTANCE_DIR}"
[ -d "${WORKSPACE_DIR}" ] && echo "  - ${WORKSPACE_DIR}" && ls -la "${WORKSPACE_DIR}"
[ -d "${PLUGINS_DIR}" ] && echo "  - ${PLUGINS_DIR}" && ls -la "${PLUGINS_DIR}"
[ -d "${STATIC_DEF_CONFIG_DIR}" ] && echo "  - ${STATIC_DEF_CONFIG_DIR}" && ls -la "${STATIC_DEF_CONFIG_DIR}"

#######################################################################
echo ">>> done"
