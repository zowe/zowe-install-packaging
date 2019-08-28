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

EXPLORER_API_LIST="jobs data-sets"
for one in $EXPLORER_API_LIST; do
  if [ "$one" = "jobs" ]; then
    ZOWE_EXPLORER_API_PORT=$ZOWE_EXPLORER_SERVER_JOBS_PORT
    ZOWE_EXPLORER_JAR_MACRO=JOBS_JAR
  elif [ "$one" = "data-sets" ]; then
    ZOWE_EXPLORER_API_PORT=$ZOWE_EXPLORER_SERVER_DATASETS_PORT
    ZOWE_EXPLORER_JAR_MACRO=DATASETS_JAR
  else
    echo "  Error: Unknown Explorer API: ${one}"
    echo "  Installation terminated"
    exit 0
  fi

  EXPLORER_INSTALL_FOLDER="explorer-${one}-api"
  cd "$ZOWE_ROOT_DIR/$EXPLORER_INSTALL_FOLDER"

  EXPLORER_API_JAR=$(ls -t ${one}-api-server-*.jar | head -1)
  if [ ! -f $EXPLORER_API_JAR ]; then
    echo "  Error: Explorer ${one} api (${one}-api-server-*.jar) missing"
    echo "  Installation terminated"
    exit 0
  fi

  # Set a+rx for Explorer API JARs. 
  chmod a+rx *.jar

  echo "About to set JAVA_HOME to $ZOWE_JAVA_HOME in start script templates" >> $LOG_FILE

  cd scripts/

  # Add JAVA_HOME to start script templates
  sed -e "s|\*\*JAVA_SETUP\*\*|export JAVA_HOME=$ZOWE_JAVA_HOME|g" \
      -e "s/\*\*${ZOWE_EXPLORER_JAR_MACRO}\*\*/${EXPLORER_API_JAR}/g" \
      -e "s/\*\*SERVER_PORT\*\*/$ZOWE_EXPLORER_API_PORT/g" \
      -e "s|\*\*KEY_ALIAS\*\*|localhost|g" \
      -e "s|\*\*KEYSTORE\*\*|$ZOWE_ROOT_DIR/api-mediation/keystore/localhost/localhost.keystore.p12|g" \
      -e "s|\*\*KEYSTORE_PASSWORD\*\*|password|g" \
      -e "s/\*\*ZOSMF_HTTPS_PORT\*\*/$ZOWE_ZOSMF_PORT/g" \
      -e "s/\*\*ZOSMF_IP\*\*/$ZOWE_ZOSMF_HOST/g" \
      "${one}-api-server-start.sh" > "${one}-api-server-start.sh.tmp"
  mv "${one}-api-server-start.sh.tmp" "${one}-api-server-start.sh"

  # Make configured script executable
  chmod -R 755 $ZOWE_ROOT_DIR/$EXPLORER_INSTALL_FOLDER/scripts
done

echo "</zowe-explorer-api-configure.sh>" >> $LOG_FILE
