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

API_MEDIATION_DIR=$ZOWE_ROOT_DIR"/components/api-mediation"

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
echo "Installing API Mediation into ${API_MEDIATION_DIR} ...">> $LOG_FILE
umask 0002
mkdir -p ${API_MEDIATION_DIR}
cd ${API_MEDIATION_DIR}
# Change to the place where we are expanding the .pax into the /api-mediation beneath the $rootDir environment variable, e.g /usr/lpp/zowe
echo "Unpax of $API_MEDIATION_PAX into $PWD" >> $LOG_FILE
pax -rf $API_MEDIATION_PAX -ppx

# TODO are these mediation steps needed (from api-ml config script)?

# Set a+rx for API Mediation JARs
chmod a+rx "${API_MEDIATION_DIR}"/*.jar 
chmod -R 751 "${API_MEDIATION_DIR}/bin"

# Make the apiml-auth plugin readable by everyone
chmod a+rx "${API_MEDIATION_DIR}/apiml-auth"
chmod a+rx "${API_MEDIATION_DIR}/apiml-auth/lib"
chmod -R a+r "${API_MEDIATION_DIR}/apiml-auth"

# TODO - move image into apiml pax
cp $INSTALL_DIR/files/assets/api-catalog.png ${API_MEDIATION_DIR}

echo "</zowe-api-mediation-install.sh>" >> $LOG_FILE
