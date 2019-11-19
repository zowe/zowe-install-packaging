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
# $ZOWE_IP_ADDRESS
# $ZOWE_APIM_EXTERNAL_CERTIFICATE
# $ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS
# $ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES
# $ZOWE_APIM_VERIFY_CERTIFICATES

echo "<zowe-api-mediation-configure.sh>" >> $LOG_FILE

API_MEDIATION_DIR=$ZOWE_ROOT_DIR"/components/api-mediation"

cd $API_MEDIATION_DIR

echo "About to set JAVA_HOME to $ZOWE_JAVA_HOME in APIML script templates" >> $LOG_FILE

cd scripts/
# Add JAVA_HOME to both script templates
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e "s/\*\*HOSTNAME\*\*/$ZOWE_EXPLORER_HOST/g" \
    -e "s/\*\*IPADDRESS\*\*/$ZOWE_IP_ADDRESS/g" \
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
echo "</zowe-api-mediation-configure.sh>" >> $LOG_FILE
