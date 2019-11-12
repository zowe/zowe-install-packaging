#!/bin/sh

#********************************************************************
# Expected globals:
# $ZOWE_APIM_ENABLE_SSO
# $CONFIG_DIR
# $ZOWE_ROOT_DIR
# $ZLUX_SERVER_CONFIG_PATH
# $TEMP_DIR
# $ZOWE_EXPLORER_HOST
# $ZOWE_ZLUX_SERVER_HTTPS_PORT
# $ZOWE_APIM_GATEWAY_PORT
# $NODE_BIN

if [ -z "$NODE_BIN" ]
then
  NODE_BIN=${NODE_HOME}/bin/node
fi

if [[ $ZOWE_APIM_ENABLE_SSO == "true" ]]; then
    # Add APIML authentication plugin to zLUX
    . $CONFIG_DIR/zowe-install-existing-plugin.sh $ZOWE_ROOT_DIR "org.zowe.zlux.auth.apiml" $ZOWE_ROOT_DIR/components/api-mediation/apiml-auth

    # Activate the plugin
    _JSON='"apiml": { "plugins": ["org.zowe.zlux.auth.apiml"] }'
    ZLUX_SERVER_CONFIG_PATH=${ZOWE_ROOT_DIR}/zlux-app-server/config
    sed 's/"zss": {/'"${_JSON}"', "zss": {/g' ${ZLUX_SERVER_CONFIG_PATH}/zluxserver.json > ${TEMP_DIR}/transform1.json
    cp ${TEMP_DIR}/transform1.json ${ZLUX_SERVER_CONFIG_PATH}/zluxserver.json
    rm ${TEMP_DIR}/transform1.json
    
    # Access API Catalog with token injector
    CATALOG_GATEWAY_URL=https://$ZOWE_EXPLORER_HOST:$ZOWE_ZLUX_SERVER_HTTPS_PORT/ZLUX/plugins/org.zowe.zlux.auth.apiml/services/tokenInjector/1.0.0/ui/v1/apicatalog/
else
    # Access API Catalog directly
    CATALOG_GATEWAY_URL=https://$ZOWE_EXPLORER_HOST:$ZOWE_APIM_GATEWAY_PORT/ui/v1/apicatalog
fi

# Add API Catalog application to zLUX - required before we issue ZLUX deploy.sh
# TODO - move into apiml config? run before deploy?
. $CONFIG_DIR/zowe-install-iframe-plugin.sh $ZOWE_ROOT_DIR "org.zowe.api.catalog" "API Catalog" $CATALOG_GATEWAY_URL $ZOWE_ROOT_DIR"/components/api-mediation/assets/api-catalog.png"

# install explorers
EXPLORERS='jes mvs uss'
for i in $(echo $EXPLORERS | sed "s/,/ /g")
do 
  iupper=$(echo $i | tr [:lower:] [:upper:])
  
  EXPLORER_CONFIG="$ZOWE_ROOT_DIR/components/explorer-${i}/bin/app/package.json"

  EXPLORER_PLUGIN_BASEURI=$($NODE_BIN -e "process.stdout.write(require('${EXPLORER_CONFIG}').config.baseuri)")
  EXPLORER_PLUGIN_ID=$($NODE_BIN -e "process.stdout.write(require('${EXPLORER_CONFIG}').config.pluginId)")
  EXPLORER_PLUGIN_NAME=$($NODE_BIN -e "process.stdout.write(require('${EXPLORER_CONFIG}').config.pluginName)")

  if [ -z "$EXPLORER_PLUGIN_ID" ]; then
    echo "  Error: cannot read plugin ID, install aborted."
    exit 0
  fi
  if [ -z "$EXPLORER_PLUGIN_NAME" ]; then
    echo "  Error: cannot read plugin name, install aborted."
    exit 0
  fi
  if [ -z "$EXPLORER_PLUGIN_BASEURI" ]; then
    echo "  Error: cannot read server base uri, install aborted."
    exit 0
  fi

  # Add explorer plugin to zLUX 
  # NOTICE: zowe-install-iframe-plugin.sh will try to automatically create install folder based on plugin name
  EXPLORER_PLUGIN_FULLURL="https://${ZOWE_EXPLORER_HOST}:${ZOWE_APIM_GATEWAY_PORT}${EXPLORER_PLUGIN_BASEURI}"
  . $ZOWE_ROOT_DIR/scripts/configure/zowe-install-iframe-plugin.sh \
      "${ZOWE_ROOT_DIR}" \
      "${EXPLORER_PLUGIN_ID}" \
      "${EXPLORER_PLUGIN_NAME}" \
      $EXPLORER_PLUGIN_FULLURL \
      "${ZOWE_ROOT_DIR}/components/explorer-${i}/bin/app/img/explorer-${iupper}.png" \
      ${ZOWE_ROOT_DIR}/components/explorer-${i}/

done