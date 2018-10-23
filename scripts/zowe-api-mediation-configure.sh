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
# $ZOWE_JAVA_HOME
# $ZOWE_ROOT_DIR
# $ZOWE_EXPLORER_HOST
# $ZOWE_IPADDRESS
# $ZOWE_APIM_CATALOG_HTTP_PORT
# $ZOWE_APIM_DISCOVERY_HTTP_PORT
# $ZOWE_APIM_GATEWAY_HTTPS_PORT

echo "<zowe-api-mediation-configure.sh>" >> $LOG_FILE

cd $ZOWE_ROOT_DIR"/api-mediation"

# Create the static api definitions folder
STATIC_DEF_CONFIG=$ZOWE_ROOT_DIR"/api-mediation/api-defs"
mkdir -p $STATIC_DEF_CONFIG

echo "About to set JAVA_HOME to $ZOWE_JAVA_HOME in APIML script templates" >> $LOG_FILE

cd scripts/
# Add JAVA_HOME to both script templates
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e 's/\*\*HOSTNAME\*\*/'$ZOWE_EXPLORER_HOST'/g' \
    -e 's/\*\*IPADDRESS\*\*/'$ZOWE_IPADDRESS'/g' \
    gen-selfsigned-keystore-template.sh > gen-selfsigned-keystore.sh

# Make configured script executable
chmod a+x gen-selfsigned-keystore.sh

# Inject parameters into API Mediation startup scripts, which contains command-line parameters as configuration
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e 's/\*\*HOSTNAME\*\*/'$ZOWE_EXPLORER_HOST'/g' \
    -e 's/\*\*IPADDRESS\*\*/'$ZOWE_IPADDRESS'/g' \
    -e 's/\*\*DISCOVERY_PORT\*\*/'$ZOWE_APIM_DISCOVERY_HTTP_PORT'/g' \
    -e 's/\*\*CATALOG_PORT\*\*/'$ZOWE_APIM_CATALOG_HTTP_PORT'/g' \
    -e 's/\*\*GATEWAY_PORT\*\*/'$ZOWE_APIM_GATEWAY_HTTPS_PORT'/g' \
    api-mediation-start-catalog-template.sh > api-mediation-start-catalog.sh

# Inject parameters into API Mediation startup, which contains command-line parameters as configuration
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e 's/\*\*HOSTNAME\*\*/'$ZOWE_EXPLORER_HOST'/g' \
    -e 's/\*\*IPADDRESS\*\*/'$ZOWE_IPADDRESS'/g' \
    -e 's/\*\*DISCOVERY_PORT\*\*/'$ZOWE_APIM_DISCOVERY_HTTP_PORT'/g' \
    -e 's/\*\*CATALOG_PORT\*\*/'$ZOWE_APIM_CATALOG_HTTP_PORT'/g' \
    -e 's/\*\*GATEWAY_PORT\*\*/'$ZOWE_APIM_GATEWAY_HTTPS_PORT'/g' \
    api-mediation-start-gateway-template.sh > api-mediation-start-gateway.sh

# Inject parameters into API Mediation startup, which contains command-line parameters as configuration
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e 's/\*\*HOSTNAME\*\*/'$ZOWE_EXPLORER_HOST'/g' \
    -e 's/\*\*IPADDRESS\*\*/'$ZOWE_IPADDRESS'/g' \
    -e 's/\*\*DISCOVERY_PORT\*\*/'$ZOWE_APIM_DISCOVERY_HTTP_PORT'/g' \
    -e 's/\*\*CATALOG_PORT\*\*/'$ZOWE_APIM_CATALOG_HTTP_PORT'/g' \
    -e 's/\*\*GATEWAY_PORT\*\*/'$ZOWE_APIM_GATEWAY_HTTPS_PORT'/g' \
    -e 's|\*\*STATIC_DEF_CONFIG\*\*|'$STATIC_DEF_CONFIG'|g' \
    api-mediation-start-discovery-template.sh > api-mediation-start-discovery.sh

# Make configured script executable
chmod a+x api-mediation-start-gateway.sh
chmod a+x api-mediation-start-discovery.sh
chmod a+x api-mediation-start-catalog.sh

cd ..

# Execute the self-signed keystore generation - no user input required
./scripts/gen-selfsigned-keystore.sh

# Add static definition for zosmf	
cat <<EOF >$TEMP_DIR/zosmf.yml
# Static definition for z/OSMF
#
# Once configured you can access z/OSMF via the API gateway:
# http --verify=no GET https://$ZOWE_EXPLORER_HOST:$ZOWE_APIM_GATEWAY_HTTPS_PORT/api/v1/zosmf/info 'X-CSRF-ZOSMF-HEADER;'
#	
services:
    - serviceId: zosmf
      instanceBaseUrls:
        - https://$ZOWE_EXPLORER_HOST:$ZOWE_ZOSMF_PORT/zosmf/
      homePageRelativeUrl:  # Home page is at the same URL
      routedServices:
        - gatewayUrl: api/v1  # [api/ui/ws]/v{majorVersion}
          serviceRelativeUrl:
EOF
iconv -f IBM-1047 -t IBM-850 $TEMP_DIR/zosmf.yml > $STATIC_DEF_CONFIG/zosmf.yml	
chmod -R 777 $STATIC_DEF_CONFIG

# Add apiml catalog tile to zlux 
CATALOG_GATEWAY_URL=https://$ZOWE_EXPLORER_HOST:$ZOWE_APIM_GATEWAY_HTTPS_PORT/ui/v1/apicatalog
. $INSTALL_DIR/scripts/zowe-install-iframe-plugin.sh $ZOWE_ROOT_DIR "org.zowe.api.catalog" "API Catalog" $CATALOG_GATEWAY_URL $INSTALL_DIR/files/assets/api-catalog.png

echo "</zowe-api-mediation-configure.sh>" >> $LOG_FILE
