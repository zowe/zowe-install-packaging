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
# $ZOWE_ROOT_DIR
# $INSTALL_DIR
# $LOG_FILE

echo "<zowe-explorer-api-install.sh>" >> $LOG_FILE

EXPLORER_API_LIST="jobs data-sets"
for one in $EXPLORER_API_LIST; do
  cd $INSTALL_DIR
  EXPLORER_API_JAR=$PWD/$(ls -t ./files/${one}-api-server-*.jar | head -1)
  if [ ! -f $EXPLORER_API_JAR ]; then
    echo "  Error: Explorer ${one} api (${one}-api-server-*.jar) missing"
    echo "  Installation terminated"
    exit 0
  fi
  EXPLORER_API_START_SCRIPT=$PWD/$(ls -t ./files/scripts/${one}-api-server-start.sh | head -1)
  if [ ! -f $EXPLORER_API_START_SCRIPT ]; then
    echo "  Error: Explorer ${one} api start script (${one}-api-server-start.sh) missing"
    echo "  Installation terminated"
    exit 0
  fi

  EXPLORER_INSTALL_FOLDER="explorer-${one}-api"
  echo "  Installing Explorer ${one} API into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."
  echo "  Installing Explorer ${one} API into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."  >> $LOG_FILE
  umask 0002
  mkdir -p "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
  # copy jar
  cd "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
  echo "  Copy ${EXPLORER_API_JAR} into ${PWD}" >> $LOG_FILE
  cp $EXPLORER_API_JAR .
  # copy start script
  mkdir scripts
  cd scripts
  cp $EXPLORER_API_START_SCRIPT .
done

echo "</zowe-explorer-api-install.sh>" >> $LOG_FILE
