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

echo "  Customizing zssCrossMemoryServerName=${ZOWE_ZSS_XMEM_SERVER_NAME} in zowe-install-apf-server.yaml" >> $LOG_FILE
zowe_install_apf_server=${INSTALL_DIR}/install/zowe-install-apf-server.yaml
sed -e "s/zssCrossMemoryServerName=ZWESIS_STD/zssCrossMemoryServerName=${ZOWE_ZSS_XMEM_SERVER_NAME}/g" ${zowe_install_apf_server} > ${XMEM_DIR}/zowe-install-apf-server.yaml

cp -r ${INSTALL_DIR}/scripts/zss "${XMEM_DIR}/scripts"
chmod -R a+rx "${XMEM_DIR}/scripts"

echo "  Copied all content over to ${XMEM_DIR}" >> $LOG_FILE 
echo "</zowe-copy-xmem.sh>" >> $LOG_FILE