
# Cache original directory, then change our directory to be here so we can rely on the script offset
PREV_DIR=`pwd`	
cd $(dirname $0)
ZOWE_ROOT_DIR={{root_dir}}

# Configure Explorer UI plugins
. zowe-configure-explorer-ui.sh

# Configure the ports for the zLUX server
. zowe-configure-zlux-ports.sh

# Configure the TLS certificates for the zLUX server
. zowe-configure-zlux-certificates.sh

if [[ $ZOWE_APIM_ENABLE_SSO == "true" ]]; then
    # Add APIML authentication plugin to zLUX
    . zowe-install-existing-plugin.sh $ZOWE_ROOT_DIR "org.zowe.zlux.auth.apiml" $ZOWE_ROOT_DIR/api-mediation/apiml-auth

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
. zowe-install-iframe-plugin.sh $ZOWE_ROOT_DIR "org.zowe.api.catalog" "API Catalog" $CATALOG_GATEWAY_URL $INSTALL_DIR/files/assets/api-catalog.png

# Run deploy on the zLUX app server to propagate the changes made
zluxserverdirectory='zlux-app-server'
echo "Preparing folder permission for zLux plugins foder..." >> $LOG_FILE
chmod -R u+w $ZOWE_ROOT_DIR/$zluxserverdirectory/plugins/

# TODO LATER - revisit to work out the best permissions, but currently needed so deploy.sh can run	
chmod -R 775 $ZOWE_ROOT_DIR/zlux-app-server/deploy/product	
chmod -R 775 $ZOWE_ROOT_DIR/zlux-app-server/deploy/instance

cd $ZOWE_ROOT_DIR/zlux-build
chmod a+x deploy.sh
./deploy.sh > /dev/null

# TODO LATER - same as the above - zss won't start with those permissions, so re-run runtime-authorise to lock it back now
$ZOWE_ROOT_DIR/scripts/zowe-runtime-authorize.sh

# Configure API Mediation layer.  Because this script may fail because of priviledge issues with the user ID
# this script is run after all the folders have been created and paxes expanded above
echo "Attempting to setup Zowe API Mediation Layer certificates ... "
. zowe-configure-api-mediation.sh

# Configure Explorer API servers. This should be after APIML CM generated certificates
echo "Attempting to setup Zowe Explorer API certificates ... "
. zowe-configure-explorer-api.sh

echo "Attempting to setup Zowe Scripts ... "
. zowe-configure-scripts.sh

sed -e "s#{{java_home}}#${ZOWE_JAVA_HOME}#" \
  -e "s#{{node_home}}#${NODE_HOME}#" \
  -e "s#{{zowe_prefix}}#${ZOWE_PREFIX}#" \
  -e "s#{{stc_name}}#${ZOWE_SERVER_PROCLIB_MEMBER}#" \
  -e "s#{{root_dir}}#${ZOWE_ROOT_DIR}#" \
  "${ZOWE_ROOT_DIR}/scripts/templates/zowe-support.template.sh" \
  > "${ZOWE_ROOT_DIR}/scripts/zowe-support.sh"
chmod a+x "${ZOWE_ROOT_DIR}/scripts/zowe-support.sh"

echo "Attempting to setup Zowe Proclib ... "
. zowe-configure-proclib.sh

cd $PREV_DIR