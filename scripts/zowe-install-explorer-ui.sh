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

# TODO add back uss and mvs
UI_PLUGIN_LIST="jes"
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
  EXPLORER_INSTALL_FOLDER="${ZOWE_ROOT_DIR}/components/${COMPONENT_ID}-explorer"
  echo "  Installing Explorer UI ${EXPLORER_PLUGIN_UPPERCASE} into ${EXPLORER_INSTALL_FOLDER} ..."  >> $LOG_FILE
  umask 0002
  mkdir -p "${EXPLORER_INSTALL_FOLDER}/bin"
  
  # unpax package
  cd "${EXPLORER_INSTALL_FOLDER}/bin"
  echo "  Unpax of ${EXPLORER_PLUGIN_PAX} into ${PWD}" >> $LOG_FILE
  pax -rf $EXPLORER_PLUGIN_PAX -ppx

  #TODO make sure scripts end up in files directory not bin.
  EXPLORER_UI_START_SCRIPT=$EXPLORER_INSTALL_FOLDER/bin/scripts/${COMPONENT_ID}-explorer-start.sh
  EXPLORER_UI_CONFIGURE_SCRIPT=$EXPLORER_INSTALL_FOLDER/bin/scripts/${COMPONENT_ID}-explorer-configure.sh
  #EXPLORER_UI_VALIDATE_SCRIPT

  if [ ! -f $EXPLORER_UI_START_SCRIPT ]; then
    echo "  Error: Explorer ${COMPONENT_ID} ui start script (start-explorer-${COMPONENT_ID}-ui-server.sh) missing"
    echo "  Installation terminated"
    exit 0
  fi

  # copy start script
  cp ${EXPLORER_UI_START_SCRIPT} start.sh

  if [[ -f ${EXPLORER_UI_CONFIGURE_SCRIPT} ]]
  then
    cp ${EXPLORER_UI_CONFIGURE_SCRIPT} configure.sh
  fi

  # if [[ -f ${EXPLORER_UI_VALIDATE_SCRIPT} ]]
  # then
  #   cp ${EXPLORER_UI_VALIDATE_SCRIPT} validate.sh
  # fi
  chmod -R 755 "${ZOWE_ROOT_DIR}/components/${COMPONENT_ID}/bin"

done

echo "</zowe-explorer-ui-install.sh>" >> $LOG_FILE
