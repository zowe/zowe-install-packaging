#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2017, 2018
################################################################################

#********************************************************************
# Expected globals:
# $ZOWE_ZOSMF_PATH
# $ZOWE_JAVA_HOME
# $ZOWE_SDSF_PATH
# $ZOWE_ROOT_DIR
# $ZOWE_EXPLORER_SERVER_HTTP_PORT
# $ZOWE_EXPLORER_SERVER_HTTPS_PORT
echo "<zowe-install-liberty-server.sh>" >> $LOG_FILE
cd $INSTALL_DIR
EXPLORER_PAX=$PWD/$(ls -t ./files/atlas-wlp-package*.pax | head -1)
if [ ! -f $EXPLORER_PAX ]
	then
	    echo "explorer-server Server PAX Archive (atlas-wlp-package*.pax) missing"
	    echo "Installation terminated"
	    exit 0
fi

# unpax the explorer server
echo "  Installing explorer-server into " $ZOWE_ROOT_DIR"/explorer-server ..."
umask 0002
mkdir -p $ZOWE_ROOT_DIR"/explorer-server"
cd $ZOWE_ROOT_DIR"/explorer-server"
# Change to the place where we are expanding the .pax into the /explorer-server beneath the $rootDir environment variable, e.g /usr/lpp/zowe 
echo "Unpax of $EXPLORER_PAX into $PWD" >> $LOG_FILE 
pax -rf $EXPLORER_PAX -ppx

# Inject the JAVA_HOME into the server.env file
echo "Injecting JAVA_HOME to $ZOWE_JAVA_HOME into server.env" >> $LOG_FILE
echo "JAVA_HOME=$ZOWE_JAVA_HOME" >> server.env

echo "Injecting ZOSMF_HOST to $ZOWE_IPADDRESS into $PWD/wlp/usr/servers/Atlas/server.env" >> $LOG_FILE
echo "ZOSMF_HOST=$ZOWE_IPADDRESS" >> server.env
iconv -f IBM-1047 -t IBM-850 server.env > ./wlp/usr/servers/Atlas/server.env
rm server.env

# Inject the http, https ports and SDSF and z/OSMF /lib dir into server.xml

echo "Injecting the http, https ports, and z/OSMF into $PWD/wlp/usr/servers/Atlas/server.xml" >> $LOG_FILE
sed -e 's|${atlashttp}|'$ZOWE_EXPLORER_SERVER_HTTP_PORT'|' -e 's|${atlashttps}|'$ZOWE_EXPLORER_SERVER_HTTPS_PORT'|g' $INSTALL_DIR/files/templates/server.xml.template > $TEMP_DIR/server.xml
iconv -f IBM-1047 -t IBM-850 $TEMP_DIR/server.xml > ./wlp/usr/servers/Atlas/server.xml

# Set permissions on any files in the atlas.pax file
chmod a+x $INSTALL_DIR/scripts/*

echo "</zowe-install-liberty-server.sh>" >> $LOG_FILE
