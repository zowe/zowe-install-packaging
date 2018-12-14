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

echo "<zowe-api-mediation-install.sh>" >> $LOG_FILE
cd $INSTALL_DIR
API_MEDIATION_PAX=$PWD/$(ls -t ./files/api-mediation-package*.pax | head -1)
if [ ! -f $API_MEDIATION_PAX ]
	then
	    echo "Api Mediation PAX Archive (api-mediation-package*.pax) missing"
	    echo "Installation terminated"
	    exit 0
fi

# unpax the API Mediation services
echo "Installing API Mediation into" $ZOWE_ROOT_DIR"/api-mediation ..."  >> $LOG_FILE
umask 0002
mkdir -p $ZOWE_ROOT_DIR"/api-mediation"
cd $ZOWE_ROOT_DIR"/api-mediation"
# Change to the place where we are expanding the .pax into the /api-mediation beneath the $rootDir environment variable, e.g /usr/lpp/zowe
echo "Unpax of $API_MEDIATION_PAX into $PWD" >> $LOG_FILE
pax -rf $API_MEDIATION_PAX -ppx

echo "</zowe-api-mediation-install.sh>" >> $LOG_FILE
