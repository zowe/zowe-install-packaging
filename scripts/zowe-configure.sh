# Configure Explorer UI plugins
. $INSTALL_DIR/scripts/zowe-explorer-ui-configure.sh

# Configure the ports for the zLUX server
. $INSTALL_DIR/scripts/zowe-zlux-configure-ports.sh

# Configure the TLS certificates for the zLUX server
. $INSTALL_DIR/scripts/zowe-zlux-configure-certificates.sh

if [[ $ZOWE_APIM_ENABLE_SSO == "true" ]]; then
    # Add APIML authentication plugin to zLUX
    . $INSTALL_DIR/scripts/zowe-install-existing-plugin.sh $ZOWE_ROOT_DIR "org.zowe.zlux.auth.apiml" $ZOWE_ROOT_DIR/api-mediation/apiml-auth

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
. $INSTALL_DIR/scripts/zowe-install-iframe-plugin.sh $ZOWE_ROOT_DIR "org.zowe.api.catalog" "API Catalog" $CATALOG_GATEWAY_URL $INSTALL_DIR/files/assets/api-catalog.png

. $INSTALL_DIR/scripts/zowe-prepare-runtime.sh
# Run deploy on the zLUX app server to propagate the changes made

# TODO LATER - revisit to work out the best permissions, but currently needed so deploy.sh can run	
chmod -R 775 $ZOWE_ROOT_DIR/zlux-app-server/deploy/product	
chmod -R 775 $ZOWE_ROOT_DIR/zlux-app-server/deploy/instance

cd $ZOWE_ROOT_DIR/zlux-build
chmod a+x deploy.sh
./deploy.sh > /dev/null

# Configure API Mediation layer.  Because this script may fail because of priviledge issues with the user ID
# this script is run after all the folders have been created and paxes expanded above
echo "Attempting to setup Zowe API Mediation Layer certificates ... "
. $INSTALL_DIR/scripts/zowe-api-mediation-configure.sh

# Configure Explorer API servers. This should be after APIML CM generated certificates
echo "Attempting to setup Zowe Explorer API certificates ... "
. $INSTALL_DIR/scripts/zowe-explorer-api-configure.sh

echo "Attempting to setup Zowe Scripts ... "
. $INSTALL_DIR/scripts/zowe-configure-scripts.sh

sed -e "s#{{java_home}}#${ZOWE_JAVA_HOME}#" \
  -e "s#{{node_home}}#${NODE_HOME}#" \
  -e "s#{{zowe_prefix}}#${ZOWE_PREFIX}#" \
  -e "s#{{stc_name}}#${ZOWE_SERVER_PROCLIB_MEMBER}#" \
  "${ZOWE_ROOT_DIR}/scripts/templates/zowe-support.template.sh" \
  > "${ZOWE_ROOT_DIR}/scripts/zowe-support.sh"
chmod a+x "${ZOWE_ROOT_DIR}/scripts/zowe-support.sh"

echo "Attempting to setup Zowe Proclib ... "
. $INSTALL_DIR/scripts/zowe-configure-proclib.sh