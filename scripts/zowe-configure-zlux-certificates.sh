#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# 5698-ZWE Copyright IBM Corp. 2018, 2019
#######################################################################

ZLUX_SERVER_CONFIG_PATH=${ZOWE_ROOT_DIR}/zlux-app-server/config
APIML_KEYSTORE_PATH=${ZOWE_ROOT_DIR}/api-mediation/keystore
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
sed 's|.*"keys".*|      "keys": ["'${APIML_KEYSTORE_PATH}'/localhost/localhost.keystore.key"]|g' zluxserver.json > ${TEMP_DIR}/transform1.json
sed 's|.*"certificates".*|    , "certificates": ["'${APIML_KEYSTORE_PATH}'/localhost/localhost.keystore.cer'${SUFFIX}'"]|g' ${TEMP_DIR}/transform1.json > ${TEMP_DIR}/transform2.json
sed 's|.*"certificateAuthorities".*|    , "certificateAuthorities": ["'${APIML_KEYSTORE_PATH}'/local_ca/localca.cer'${SUFFIX}'"]|g' ${TEMP_DIR}/transform2.json > zluxserver.json

echo "</zowe-zlux-configure-certificates.sh>" >> $LOG_FILE
