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
# $ZOWE_EXPLORER_SERVER_JOBS_PORT
# $ZOWE_EXPLORER_SERVER_DATASETS_PORT
# $ZOWE_IPADDRESS
# $ZOWE_ZOSMF_PORT

echo "<zowe-explorer-api-configure.sh>" >> $LOG_FILE

#############################################
# Configure explorer jobs api started
EXPLORER_INSTALL_FOLDER=explorer-jobs-api
cd "$ZOWE_ROOT_DIR/$EXPLORER_INSTALL_FOLDER"

EXPLORER_JOBS_JAR=$(ls -t jobs-api-server-*.jar | head -1)
if [ ! -f $EXPLORER_JOBS_JAR ]; then
  echo "Explorer jobs api (jobs-api-server-*.jar) missing"
  echo "Installation terminated"
  exit 0
fi

# Set a+rx for Explorer API JARs. 
chmod a+rx *.jar

echo "About to set JAVA_HOME to $ZOWE_JAVA_HOME in start script templates" >> $LOG_FILE

cd scripts/

# Add JAVA_HOME to start script templates
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e 's/\*\*JOBS_JAR\*\*/'$EXPLORER_JOBS_JAR'/g' \
    -e 's/\*\*SERVER_PORT\*\*/'$ZOWE_EXPLORER_SERVER_JOBS_PORT'/g' \
    -e "s|\*\*KEY_ALIAS\*\*|localhost|g" \
    -e "s|\*\*KEYSTORE\*\*|$ZOWE_ROOT_DIR/api-mediation/keystore/localhost/localhost.keystore.p12|g" \
    -e "s|\*\*KEYSTORE_PASSWORD\*\*|password|g" \
    -e 's/\*\*ZOSMF_HTTPS_PORT\*\*/'$ZOWE_ZOSMF_PORT'/g' \
    -e 's/\*\*ZOSMF_IP\*\*/'$ZOWE_IPADDRESS'/g' \
    jobs-api-server-start.sh > jobs-api-server-start.sh.tmp
mv jobs-api-server-start.sh.tmp jobs-api-server-start.sh

# Make configured script executable
chmod a+x *.sh
chmod 755 $ZOWE_ROOT_DIR/$EXPLORER_INSTALL_FOLDER/scripts
# Configure explorer jobs api ended
#############################################

#############################################
# Configure explorer data sets api started
EXPLORER_INSTALL_FOLDER=explorer-data-sets-api
cd "$ZOWE_ROOT_DIR/$EXPLORER_INSTALL_FOLDER"

EXPLORER_DATASETS_JAR=$(ls -t data-sets-api-server-*-boot.jar | head -1)
if [ ! -f $EXPLORER_DATASETS_JAR ]; then
  echo "Explorer data sets api (data-sets-api-server-*-boot.jar) missing"
  echo "Installation terminated"
  exit 0
fi

# Set a+rx for Explorer API JARs. 
chmod a+rx *.jar

echo "About to set JAVA_HOME to $ZOWE_JAVA_HOME in start script templates" >> $LOG_FILE

cd scripts/

# Add JAVA_HOME to start script templates
sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
    -e 's/\*\*DATASETS_JAR\*\*/'$EXPLORER_DATASETS_JAR'/g' \
    -e 's/\*\*SERVER_PORT\*\*/'$ZOWE_EXPLORER_SERVER_DATASETS_PORT'/g' \
    -e "s|\*\*KEY_ALIAS\*\*|localhost|g" \
    -e "s|\*\*KEYSTORE\*\*|$ZOWE_ROOT_DIR/api-mediation/keystore/localhost/localhost.keystore.p12|g" \
    -e "s|\*\*KEYSTORE_PASSWORD\*\*|password|g" \
    -e 's/\*\*ZOSMF_HTTPS_PORT\*\*/'$ZOWE_ZOSMF_PORT'/g' \
    -e 's/\*\*ZOSMF_IP\*\*/'$ZOWE_IPADDRESS'/g' \
    data-sets-api-server-start.sh > data-sets-api-server-start.sh.tmp
mv data-sets-api-server-start.sh.tmp data-sets-api-server-start.sh

# Make configured script executable
chmod a+x *.sh
chmod 755 $ZOWE_ROOT_DIR/$EXPLORER_INSTALL_FOLDER/scripts
# Configure explorer data sets api ended
#############################################

echo "</zowe-explorer-api-configure.sh>" >> $LOG_FILE
