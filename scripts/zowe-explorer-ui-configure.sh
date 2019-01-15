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
# $NODE_HOME
# $LOG_FILE
# $ZOWE_EXPLORER_HOST
# $ZOWE_EXPLORER_JES_UI_PORT
# $ZOWE_EXPLORER_MVS_UI_PORT
# $ZOWE_EXPLORER_USS_UI_PORT
# $ZOWE_APIM_GATEWAY_PORT

echo "<zowe-explorer-ui-configure.sh>" >> $LOG_FILE

# define node bin
NODE_BIN="$NODE_HOME/bin/node"
if [ ! -f $NODE_BIN ]; then
  echo "Error: cannot find node bin: ${NODE_BIN}, explorer UI plugins are not installed."
  echo "Error: cannot find node bin: ${NODE_BIN}, explorer UI plugins are not installed." >> $LOG_FILE
  exit 0
fi
# define zlux certs from apiml keystore
APIML_KEYSTORE_PATH=${ZOWE_ROOT_DIR}/api-mediation/keystore
SUFFIX=""
if [ `uname` = "OS/390" ]; then
  SUFFIX="-ebcdic"
fi
ZLUX_CERTIFICATE_KEY="${APIML_KEYSTORE_PATH}/localhost/localhost.keystore.key"
ZLUX_CERTIFICATE_CERT="${APIML_KEYSTORE_PATH}/localhost/localhost.keystore.cer${SUFFIX}"


UI_PLUGIN_LIST="jes mvs uss"
for one in $UI_PLUGIN_LIST; do
  EXPLORER_PLUGIN_UPPERCASE=$(echo $one | tr '[a-z]' '[A-Z]')
  EXPLORER_PLUGIN_PORT_VAR="ZOWE_EXPLORER_${EXPLORER_PLUGIN_UPPERCASE}_UI_PORT"
  eval EXPLORER_PLUGIN_PORT='$'$EXPLORER_PLUGIN_PORT_VAR

  echo "  Configuring Explorer UI: ${EXPLORER_PLUGIN_UPPERCASE} ..."
  echo "  Configuring Explorer UI: ${EXPLORER_PLUGIN_UPPERCASE} ..." >> $LOG_FILE

  # NOTICE: zowe-install-iframe-plugin.sh will try to automatically create install folder based on plugin name
  EXPLORER_INSTALL_FOLDER=${one}_explorer
  cd "$ZOWE_ROOT_DIR/$EXPLORER_INSTALL_FOLDER"

  EXPLORER_PLUGIN_BASEURI=$($NODE_BIN -e "process.stdout.write(require('./package.json').config.baseuri)")
  EXPLORER_PLUGIN_ID=$($NODE_BIN -e "process.stdout.write(require('./package.json').config.pluginId)")
  EXPLORER_PLUGIN_NAME=$($NODE_BIN -e "process.stdout.write(require('./package.json').config.pluginName)")
  echo "    - plugin ID   : ${EXPLORER_PLUGIN_ID}"
  echo "    - plugin ID   : ${EXPLORER_PLUGIN_ID}" >> $LOG_FILE
  echo "    - plugin name : ${EXPLORER_PLUGIN_NAME}"
  echo "    - plugin name : ${EXPLORER_PLUGIN_NAME}" >> $LOG_FILE
  echo "    - port        : ${EXPLORER_PLUGIN_PORT}"
  echo "    - port        : ${EXPLORER_PLUGIN_PORT}" >> $LOG_FILE
  echo "    - base uri    : ${EXPLORER_PLUGIN_BASEURI}"
  echo "    - base uri    : ${EXPLORER_PLUGIN_BASEURI}" >> $LOG_FILE
  if [ -z "$EXPLORER_PLUGIN_ID" ]; then
    echo "  Error: cannot read plugin ID, install aborted."
    echo "  Error: cannot read plugin ID, install aborted." >> $LOG_FILE
    exit 0
  fi
  if [ -z "$EXPLORER_PLUGIN_NAME" ]; then
    echo "  Error: cannot read plugin name, install aborted."
    echo "  Error: cannot read plugin name, install aborted." >> $LOG_FILE
    exit 0
  fi
  if [ -z "$EXPLORER_PLUGIN_BASEURI" ]; then
    echo "  Error: cannot read server base uri, install aborted."
    echo "  Error: cannot read server base uri, install aborted." >> $LOG_FILE
    exit 0
  fi

  # make scripts executable
  cd scripts
  chmod +x *.sh
  cd ..

  # update default config.json
  cd server/configs
  # - replace port from zowe configuration
  # - replace certificates
  sed -e "s|\"port\":.\+,|\"port\": ${EXPLORER_PLUGIN_PORT},|g" \
      -e "s|\"port\":[^,]\+|\"port\": ${EXPLORER_PLUGIN_PORT}|g" \
      -e "s|\"key\":[^,]\+,|\"key\": \"${ZLUX_CERTIFICATE_KEY}\",|g" \
      -e "s|\"key\":[^,]\+|\"key\": \"${ZLUX_CERTIFICATE_KEY}\"|g" \
      -e "s|\"cert\":[^,]\+,|\"cert\": \"${ZLUX_CERTIFICATE_CERT}\",|g" \
      -e "s|\"cert\":[^,]\+|\"cert\": \"${ZLUX_CERTIFICATE_CERT}\"|g" \
      config.json > config.json.tmp
  mv config.json.tmp config.json
  cd ../..

  # Add explorer plugin to zLUX 
  EXPLORER_PLUGIN_FULLURL="https://${ZOWE_EXPLORER_HOST}:${ZOWE_APIM_GATEWAY_PORT}${EXPLORER_PLUGIN_BASEURI}"
  . $INSTALL_DIR/scripts/zowe-install-iframe-plugin.sh \
      "$ZOWE_ROOT_DIR" \
      "${EXPLORER_PLUGIN_ID}" \
      "${EXPLORER_PLUGIN_NAME}" \
      $EXPLORER_PLUGIN_FULLURL \
      "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}/plugin-definition/zlux/images/explorer-${EXPLORER_PLUGIN_UPPERCASE}.png"

  echo "  ${EXPLORER_PLUGIN_UPPERCASE} Explorer UI configured."
  echo "  ${EXPLORER_PLUGIN_UPPERCASE} Explorer UI configured." >> $LOG_FILE
done

echo "</zowe-explorer-ui-configure.sh>" >> $LOG_FILE
