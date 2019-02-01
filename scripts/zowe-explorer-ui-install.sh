#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

#********************************************************************
# Expected globals:
# $ZOWE_ROOT_DIR
# $INSTALL_DIR
# $LOG_FILE

echo "<zowe-explorer-ui-install.sh>" >> $LOG_FILE

UI_PLUGIN_LIST="jes mvs uss"
for one in $UI_PLUGIN_LIST; do
  EXPLORER_PLUGIN_UPPERCASE=$(echo $one | tr '[a-z]' '[A-Z]')

  cd $INSTALL_DIR
  EXPLORER_PLUGIN_PAX=$PWD/$(ls -t ./files/explorer-${one}-*.pax | head -1)
  if [ ! -f $EXPLORER_PLUGIN_PAX ]; then
    echo "  ${EXPLORER_PLUGIN_UPPERCASE} Explorer UI (explorer-${one}-*.pax) missing"
    echo "  Installation terminated"
    exit 0
  fi

  # NOTICE: zowe-install-iframe-plugin.sh will try to automatically create install folder based on plugin name
  EXPLORER_INSTALL_FOLDER="${one}_explorer"
  echo "  Installing Explorer UI ${EXPLORER_PLUGIN_UPPERCASE} into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."  >> $LOG_FILE
  umask 0002
  mkdir -p "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
  # unpax package
  cd "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
  echo "  Unpax of ${EXPLORER_PLUGIN_PAX} into ${PWD}" >> $LOG_FILE
  pax -rf $EXPLORER_PLUGIN_PAX -ppx
done

echo "</zowe-explorer-ui-install.sh>" >> $LOG_FILE
