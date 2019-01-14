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
# $ZOWE_ROOT_DIR
# $INSTALL_DIR
# $LOG_FILE

echo "<zowe-explorer-api-install.sh>" >> $LOG_FILE

#############################################
# Install explorer jobs api started
cd $INSTALL_DIR
EXPLORER_JOBS_JAR=$PWD/$(ls -t ./files/jobs-api-server-*.jar | head -1)
if [ ! -f $EXPLORER_JOBS_JAR ]; then
  echo "Explorer jobs api (jobs-api-server-*.jar) missing"
  echo "Installation terminated"
  exit 0
fi
EXPLORER_JOBS_START_SCRIPT=$PWD/$(ls -t ./files/scripts/jobs-api-server-start.sh | head -1)
if [ ! -f $EXPLORER_JOBS_START_SCRIPT ]; then
  echo "Explorer jobs api start script (jobs-api-server-start.sh) missing"
  echo "Installation terminated"
  exit 0
fi

EXPLORER_INSTALL_FOLDER=explorer-jobs-api
echo "Installing Explorer Jobs API into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."
echo "Installing Explorer Jobs API into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."  >> $LOG_FILE
umask 0002
mkdir -p "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
# copy jar
cd "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
echo "Copy ${EXPLORER_JOBS_JAR} into ${PWD}" >> $LOG_FILE
cp $EXPLORER_JOBS_JAR .
# copy start script
mkdir scripts
cd scripts
cp $EXPLORER_JOBS_START_SCRIPT .
# Install explorer jobs api ended
#############################################


#############################################
# Install explorer data sets api started
cd $INSTALL_DIR
EXPLORER_DATASETS_JAR=$PWD/$(ls -t ./files/data-sets-api-server-*-boot.jar | head -1)
if [ ! -f $EXPLORER_DATASETS_JAR ]; then
  echo "Explorer data sets api (data-sets-api-server-*-boot.jar) missing"
  echo "Installation terminated"
  exit 0
fi
EXPLORER_DATASETS_START_SCRIPT=$PWD/$(ls -t ./files/scripts/data-sets-api-server-start.sh | head -1)
if [ ! -f $EXPLORER_DATASETS_START_SCRIPT ]; then
  echo "Explorer data sets api start script (data-sets-api-server-start.sh) missing"
  echo "Installation terminated"
  exit 0
fi

EXPLORER_INSTALL_FOLDER=explorer-data-sets-api
echo "Installing Explorer Data Sets API into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."
echo "Installing Explorer Data Sets API into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."  >> $LOG_FILE
umask 0002
mkdir -p "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
# copy jar
cd "${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER}"
echo "Copy ${EXPLORER_DATASETS_JAR} into ${PWD}" >> $LOG_FILE
cp $EXPLORER_DATASETS_JAR .
# copy start script
mkdir scripts
cd scripts
cp $EXPLORER_DATASETS_START_SCRIPT .
# Install explorer data sets api ended
#############################################

echo "</zowe-explorer-api-install.sh>" >> $LOG_FILE
