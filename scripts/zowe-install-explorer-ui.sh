#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2020
################################################################################

#********************************************************************
# Expected globals:
# $ZOWE_ROOT_DIR
# $INSTALL_DIR
# $LOG_FILE

echo "<zowe-explorer-ui-install.sh>" >> $LOG_FILE

# install explorer-ui-server
cd $INSTALL_DIR
EXPLORER_SERVER_PAX=$PWD/$(ls -t ./files/explorer-ui-server-*.pax | head -1)
EXPLORER_INSTALL_FOLDER=${ZOWE_ROOT_DIR}/components/explorer-ui-server
echo "  Installing explorer-ui-server into ${EXPLORER_INSTALL_FOLDER} ..."  >> $LOG_FILE
umask 0002
mkdir -p "${EXPLORER_INSTALL_FOLDER}"
cd ${EXPLORER_INSTALL_FOLDER}
echo "  Unpax of ${EXPLORER_SERVER_PAX} into ${PWD}" >> $LOG_FILE
pax -rf ${EXPLORER_SERVER_PAX} -ppx
chmod -R 755 .


UI_PLUGIN_LIST="jes mvs uss"
for COMPONENT_ID in $UI_PLUGIN_LIST; do
  EXPLORER_PLUGIN_UPPERCASE=$(echo $COMPONENT_ID | tr '[a-z]' '[A-Z]')

  cd $INSTALL_DIR
  EXPLORER_PLUGIN_PAX=$PWD/$(ls -t ./files/explorer-${COMPONENT_ID}-*.pax | head -1)
  if [ ! -f $EXPLORER_PLUGIN_PAX ]; then
    echo "  ${EXPLORER_PLUGIN_UPPERCASE} Explorer UI (explorer-${COMPONENT_ID}-*.pax) missing"
    echo "  Installation terminated"
    exit 0
  fi

  # NOTICE: zowe-install-iframe-plugin.sh will try to automatically create install folder based on plugin name
  EXPLORER_INSTALL_FOLDER="${ZOWE_ROOT_DIR}/components/explorer-${COMPONENT_ID}"
  echo "  Installing Explorer UI ${EXPLORER_PLUGIN_UPPERCASE} into ${EXPLORER_INSTALL_FOLDER} ..."  >> $LOG_FILE
  umask 0002
  mkdir -p "${EXPLORER_INSTALL_FOLDER}/bin"
  
  # unpax package
  cd "${EXPLORER_INSTALL_FOLDER}/bin"
  echo "  Unpax of ${EXPLORER_PLUGIN_PAX} into ${PWD}" >> $LOG_FILE
  pax -rf $EXPLORER_PLUGIN_PAX -ppx

  EXPLORER_UI_START_SCRIPT=$EXPLORER_INSTALL_FOLDER/bin/scripts/explorer-${COMPONENT_ID}-start.sh
  EXPLORER_UI_CONFIGURE_SCRIPT=$EXPLORER_INSTALL_FOLDER/bin/scripts/explorer-${COMPONENT_ID}-configure.sh
  EXPLORER_UI_VALIDATE_SCRIPT=$EXPLORER_INSTALL_FOLDER/bin/scripts/explorer-${COMPONENT_ID}-validate.sh

  if [ ! -f $EXPLORER_UI_START_SCRIPT ]; then
    echo "  Error: Explorer ${COMPONENT_ID} ui start script (start-explorer-${COMPONENT_ID}-ui-server.sh) missing"
    echo "  Installation terminated"
    exit 0
  fi

  # copy start script
  mv ${EXPLORER_UI_START_SCRIPT} start.sh

  if [[ -f ${EXPLORER_UI_CONFIGURE_SCRIPT} ]]
  then
    mv ${EXPLORER_UI_CONFIGURE_SCRIPT} configure.sh
  fi

  if [[ -f ${EXPLORER_UI_VALIDATE_SCRIPT} ]]
  then
    mv ${EXPLORER_UI_VALIDATE_SCRIPT} validate.sh
  fi

  rm -rf $EXPLORER_INSTALL_FOLDER/bin/scripts

  chmod -R 755 "${ZOWE_ROOT_DIR}/components/explorer-${COMPONENT_ID}/bin"

done

echo "</zowe-explorer-ui-install.sh>" >> $LOG_FILE
