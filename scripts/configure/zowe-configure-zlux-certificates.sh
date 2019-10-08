#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Broadcom 2018
################################################################################

ZLUX_SERVER_CONFIG_PATH=${ZOWE_ROOT_DIR}/zlux-app-server/config
APIML_KEYSTORE_PATH=${ZOWE_ROOT_DIR}/components/api-mediation/keystore
SUFFIX=""
if [ `uname` = "OS/390" ]; then
  SUFFIX="-ebcdic"
fi

echo "<zowe-zlux-configure-certificates.sh>" >> $LOG_FILE

# Change the permission to allow us to write and modify the port numbers
chmod -R u+w ${ZLUX_SERVER_CONFIG_PATH}/
cd ${ZLUX_SERVER_CONFIG_PATH}

# Update the /zlux-app-server/deploy/instance/ZLUX/serverConfig/zluxserver.json
echo "Updating certificates in zluxserver.json to use key store in ${APIML_KEYSTORE_PATH}" >> $LOG_FILE 

#concatenate all CA (including optional external CA) into one string separated by ","
CA_LIST=${APIML_KEYSTORE_PATH}'/local_ca/localca.cer'${SUFFIX}
for cert_entry in $APIML_KEYSTORE_PATH/local_ca/extca*.cer${SUFFIX} ; do    
    if [ -e "${cert_entry}" ]; then
        CA_LIST="${CA_LIST}"'","'"${cert_entry}"
        echo "External CA: $cert_entry" >> $LOG_FILE         
    fi
done

sed 's|.*"keys".*|      "keys": ["'${APIML_KEYSTORE_PATH}'/localhost/localhost.keystore.key"]|g' zluxserver.json > ${TEMP_DIR}/transform1.json
sed 's|.*"certificates".*|    , "certificates": ["'${APIML_KEYSTORE_PATH}'/localhost/localhost.keystore.cer'${SUFFIX}'"]|g' ${TEMP_DIR}/transform1.json > ${TEMP_DIR}/transform2.json
sed 's|.*"certificateAuthorities".*|    , "certificateAuthorities": ["'$CA_LIST'"]|g' ${TEMP_DIR}/transform2.json > zluxserver.json

echo "</zowe-zlux-configure-certificates.sh>" >> $LOG_FILE
