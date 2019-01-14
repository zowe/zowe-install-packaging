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

# update the /zlux-example-server/deploy/instance/ZLUX/serverConfig/zluxserver.json
ZLUX_SERVER_CONFIG_PATH=$ZOWE_ROOT_DIR/zlux-example-server/config/
echo "<zowe-zlux-configure-ports.sh>" >> $LOG_FILE
# Change the permission to allow us to write and modify the port numbers
chmod -R u+w $ZLUX_SERVER_CONFIG_PATH/
cd $ZLUX_SERVER_CONFIG_PATH/

echo "Updating ports in zluxserver.json "$ZOWE_ZLUX_SERVER_HTTPS_PORT";"$ZOWE_ZSS_SERVER_PORT  >> $LOG_FILE 
sed 's/"port": 8544,/"port": '"${ZOWE_ZLUX_SERVER_HTTPS_PORT}",'/g' zluxserver.json > $TEMP_DIR/transform1.json
sed 's/"zssPort":8542/"zssPort": '"${ZOWE_ZSS_SERVER_PORT}"'/g' $TEMP_DIR/transform1.json > $TEMP_DIR/transform3.json
if grep -q gatewayPort "zluxserver.json"; then
    sed 's/"gatewayPort":10010/"gatewayPort": '"${ZOWE_APIM_GATEWAY_PORT}"'/g' $TEMP_DIR/transform3.json > zluxserver.json
else
    sed 's/"hostname"/"gatewayPort": '"${ZOWE_APIM_GATEWAY_PORT}"', "hostname"/g' $TEMP_DIR/transform3.json > zluxserver.json
fi

# SSH port for the VT terminal app
echo "Updating port in _defaultVT.json to "$ZOWE_ZLUX_SSH_PORT >> $LOG_FILE 
chmod -R u+w ../../vt-ng2/
sed 's/"port": 22,/"port": '"${ZOWE_ZLUX_SSH_PORT}",'/g' ../../vt-ng2/_defaultVT.json > $TEMP_DIR/_defaultVT.json
mv $TEMP_DIR/_defaultVT.json ../../vt-ng2/_defaultVT.json

# Telnet port for the 3270 emulator app
echo "Updating port in _defaultTN3270.json to "$ZOWE_ZLUX_TELNET_PORT >> $LOG_FILE 
chmod -R u+w ../../tn3270-ng2/
sed 's/"port": 23,/"port": '"${ZOWE_ZLUX_TELNET_PORT}",'/g' ../../tn3270-ng2/_defaultTN3270.json > $TEMP_DIR/_defaultTN3270.json
mv $TEMP_DIR/_defaultTN3270.json ../../tn3270-ng2/_defaultTN3270.json

if [[ -n "${ZOWE_ZLUX_SECURITY_TYPE}" ]]
then
    echo "Updating security type in _defaultTN3270.json to "$ZOWE_ZLUX_SECURITY_TYPE >> $LOG_FILE 
    sed 's/"type": "telnet"/"type": "'"${ZOWE_ZLUX_SECURITY_TYPE}"'"/' ../../tn3270-ng2/_defaultTN3270.json > $TEMP_DIR/_defaultTN3270.json
    mv $TEMP_DIR/_defaultTN3270.json ../../tn3270-ng2/_defaultTN3270.json
fi 
echo "</zowe-zlux-configure-ports.sh>" >> $LOG_FILE
