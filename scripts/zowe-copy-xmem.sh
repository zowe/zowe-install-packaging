#!/bin/sh

 ################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019
################################################################################

 #********************************************************************
# Expected globals:
# $ZOWE_ROOT_DIR
# $INSTALL_DIR
# $LOG_FILE

echo "<zowe-copy-xmem.sh>" >> $LOG_FILE
XMEM_DIR=$ZOWE_ROOT_DIR"/xmem-server"
XMEM_SCRIPTS_DIR="${XMEM_DIR}/scripts"

echo "  Creating xms directory ${XMEM_DIR}" >> $LOG_FILE
mkdir -p ${XMEM_DIR}

cp ${INSTALL_DIR}/files/zss.pax ${XMEM_DIR}
cp ${INSTALL_DIR}/install/zowe-install-apf-server.yaml ${XMEM_DIR}
sed -e "s#SCRIPT_DIR=.*#SCRIPT_DIR=${XMEM_SCRIPTS_DIR}#" \
  -e "s#ZSS=.*#ZSS=${XMEM_DIR}/zss#" \
  -e "s#INSTALL_DIR=.*#\#INSTALL_DIR not needed#" \
  -e "s#OPERCMD=.*#OPERCMD=${ZOWE_ROOT_DIR}/scripts/internal/opercmd#" \
  "${INSTALL_DIR}/install/zowe-install-apf-server.sh" \
  > "${XMEM_DIR}/zowe-install-apf-server.sh"
chmod -R a+rx "${XMEM_DIR}/zowe-install-apf-server.sh"

cp -r ${INSTALL_DIR}/scripts/zss "${XMEM_SCRIPTS_DIR}"
chmod -R a+rx "${XMEM_SCRIPTS_DIR}"

echo "  Copied all content over to ${XMEM_DIR}" >> $LOG_FILE

echo "</zowe-copy-xmem.sh>" >> $LOG_FILE 