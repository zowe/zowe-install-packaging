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
    api-mediation-start-discovery-template.sh > api-mediation-start-discovery.sh

# Make configured script executable
chmod a+x api-mediation-start-gateway.sh
chmod a+x api-mediation-start-discovery.sh
chmod a+x api-mediation-start-catalog.sh

cd ..

# Execute the self-signed keystore generation - no user input required
./scripts/gen-selfsigned-keystore.sh

echo "</zowe-api-mediation-configure.sh>" >> $LOG_FILE
