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
# $ZOWE_JAVA_HOME
# $ZOWE_ROOT_DIR
# $ZOWE_EXPLORER_HOST
# $ZOWE_IPADDRESS
# $ZOWE_APIM_EXTERNAL_CERTIFICATE
# $ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS
# $ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES
# $ZOWE_APIM_VERIFY_CERTIFICATES

echo "<zowe-api-mediation-configure.sh>" >> $LOG_FILE

API_MEDIATION_DIR=$ZOWE_ROOT_DIR"/components/api-mediation"

cd $API_MEDIATION_DIR

# Create the static api definitions folder
STATIC_DEF_CONFIG=$API_MEDIATION_DIR"/api-defs"
mkdir -p $STATIC_DEF_CONFIG

echo "About to set JAVA_HOME to $ZOWE_JAVA_HOME in APIML script templates" >> $LOG_FILE

cd scripts/
# Add JAVA_HOME to both script templates
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e "s/\*\*HOSTNAME\*\*/$ZOWE_EXPLORER_HOST/g" \
    -e "s/\*\*IPADDRESS\*\*/$ZOWE_IPADDRESS/g" \
    -e "s/\*\*VERIFY_CERTIFICATES\*\*/$ZOWE_APIM_VERIFY_CERTIFICATES/g" \
    -e "s/\*\*ZOSMF_KEYRING\*\*/$ZOWE_ZOSMF_KEYRING/g" \
    -e "s/\*\*ZOSMF_USER\*\*/$ZOWE_ZOSMF_USERID/g" \
    -e "s|\*\*EXTERNAL_CERTIFICATE\*\*|$ZOWE_APIM_EXTERNAL_CERTIFICATE|g" \
    -e "s|\*\*EXTERNAL_CERTIFICATE_ALIAS\*\*|$ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS|g" \
    -e "s|\*\*EXTERNAL_CERTIFICATE_AUTHORITIES\*\*|$ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES|g" \
    -e "s|\*\*ZOWE_ROOT_DIR\*\*|$ZOWE_ROOT_DIR|g" \
    setup-apiml-certificates-template.sh > setup-apiml-certificates.sh

# Make configured script executable
chmod a+x setup-apiml-certificates.sh

# Make the scripts read and executable
chmod -R 750 "${API_MEDIATION_DIR}/scripts"

cd ..

# Execute the APIML certificate generation - no user input required
echo "  Setting up Zowe API Mediation Layer certificates..."
./scripts/setup-apiml-certificates.sh >> $LOG_FILE
echo "  Certificate setup done."

chmod -R 750 "${API_MEDIATION_DIR}/keystore"

# Add static definition for MVS datasets
cat <<EOF >$TEMP_DIR/datasets_ui.yml
#
services:
  - serviceId: explorer-mvs
    title: IBM z/OS MVS Explorer UI
    description: IBM z/OS MVS Explorer UI service
    catalogUiTileId:
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_MVS_UI_PORT/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: ui/v1
        serviceRelativeUrl: ui/v1/explorer-mvs
EOF
iconv -f IBM-1047 -t IBM-850 $TEMP_DIR/datasets_ui.yml > $STATIC_DEF_CONFIG/datasets_ui.yml	

# Add static definition for Jobs
cat <<EOF >$TEMP_DIR/jobs_ui.yml
#
services:
  - serviceId: explorer-jes
    title: IBM z/OS Jobs UI
    description: IBM z/OS Jobs UI service
    catalogUiTileId:
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_JES_UI_PORT/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: ui/v1
        serviceRelativeUrl: ui/v1/explorer-jes
EOF
iconv -f IBM-1047 -t IBM-850 $TEMP_DIR/jobs_ui.yml > $STATIC_DEF_CONFIG/jobs_ui.yml	

# Add static definition for USS
cat <<EOF >$TEMP_DIR/uss.yml
#
services:
  - serviceId: explorer-uss
    title: IBM Unix System Services
    description: IBM z/OS Unix System services UI
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_USS_UI_PORT/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: ui/v1
        serviceRelativeUrl: ui/v1/explorer-uss
EOF
iconv -f IBM-1047 -t IBM-850 $TEMP_DIR/uss.yml > $STATIC_DEF_CONFIG/uss.yml	

#Make the static defs read/write to owner/group (so that IZUSVR can read them)
chmod -R 750 ${STATIC_DEF_CONFIG}

echo "</zowe-api-mediation-configure.sh>" >> $LOG_FILE
