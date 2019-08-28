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

echo "  Customizing zssCrossMemoryServerName=${ZOWE_ZSS_XMEM_SERVER_NAME} in zowe-install-apf-server.yaml"
zowe_install_apf_server=${INSTALL_DIR}/install/zowe-install-apf-server.yaml
cp ${zowe_install_apf_server} ${zowe_install_apf_server}.orig
sed -e "s/zssCrossMemoryServerName=ZWESIS_STD/zssCrossMemoryServerName=${ZOWE_ZSS_XMEM_SERVER_NAME}/g" ${zowe_install_apf_server}.orig > ${zowe_install_apf_server}
cp ${zowe_install_apf_server} ${XMEM_DIR}

# SH: sed injection is a mess as we need to get multiple commands in and varaibles they can't be evaluated at copy time due to smpe running in a different root from the install location
sed -e "s#INSTALL_DIR=.*#cd ../ \&\& export ZOWE_ROOT_DIR=\`pwd\` \&\& cd ${ZOWE_ROOT_DIR}/xmem-server \#we are in <ZOWE_ROOT_DIR>/xmem-server#" \
  -e "s#SCRIPT_DIR=.*#SCRIPT_DIR=\${ZOWE_ROOT_DIR}/xmem-server/scripts#" \
  -e "s#ZSS=.*#ZSS=\${ZOWE_ROOT_DIR}/xmem-server/zss#" \
  -e "s#OPERCMD=.*#OPERCMD=\${ZOWE_ROOT_DIR}/scripts/internal/opercmd#" \
  "${INSTALL_DIR}/install/zowe-install-apf-server.sh" \
  > "${XMEM_DIR}/zowe-install-apf-server.sh"
chmod -R a+rx "${XMEM_DIR}/zowe-install-apf-server.sh"

cp -r ${INSTALL_DIR}/scripts/zss "${XMEM_DIR}/scripts"
chmod -R a+rx "${XMEM_DIR}/scripts"

echo "  Copied all content over to ${XMEM_DIR}" >> $LOG_FILE 
echo "</zowe-copy-xmem.sh>" >> $LOG_FILE