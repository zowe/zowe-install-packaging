#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

#********************************************************************
# Expected globals:
# $ZOWE_ROOT_DIR
# $INSTALL_DIR
# $LOG_FILE

echo "<zowe-explorer-ui-install.sh>" >> $LOG_FILE
cd $INSTALL_DIR

#############################################
# Install explorer-jes started
EXPLORER_JES_PAX=$PWD/$(ls -t ./files/explorer-jes-*.pax | head -1)
if [ ! -f $EXPLORER_JES_PAX ]; then
  echo "JES Explorer UI (explorer-jes*.pax) missing"
  echo "Installation terminated"
  exit 0
fi
#############################################
# Install explorer-uss started
EXPLORER_USS_PAX=$PWD/$(ls -t ./files/explorer-uss-*.pax | head -1)
if [ ! -f $EXPLORER_USS_PAX ]; then
  echo "USS Explorer UI (explorer-uss*.pax) missing"
  echo "Installation terminated"
  exit 0
fi

# NOTICE: zowe-install-iframe-plugin.sh will try to automatically create install folder based on plugin name
EXPLORER_INSTALL_FOLDER=jes_explorer
echo "Installing Explorer JES into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."
echo "Installing Explorer JES into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."  >> $LOG_FILE
umask 0002
# remove old folders installed by atlas
# rm -fr "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}" 2&>1 >/dev/null
mkdir -p "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
# unpax package
cd "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
echo "Unpax of ${EXPLORER_JES_PAX} into ${PWD}" >> $LOG_FILE
pax -rf $EXPLORER_JES_PAX -ppx
# Install explorer-jes ended
#############################################


# NOTICE: zowe-install-iframe-plugin.sh will try to automatically create install folder based on plugin name
EXPLORER_INSTALL_FOLDER=uss_explorer
echo "Installing Explorer USS into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."
echo "Installing Explorer USS into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."  >> $LOG_FILE
umask 0002
mkdir -p "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
# unpax package
cd "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
echo "Unpax of ${EXPLORER_USS_PAX} into ${PWD}" >> $LOG_FILE
pax -rf $EXPLORER_USS_PAX -ppx
# Install explorer-uss ended
#############################################

echo "</zowe-explorer-ui-install.sh>" >> $LOG_FILE
