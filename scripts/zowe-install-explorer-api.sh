#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2018, 2020
#######################################################################

# Expected globals:
# $ZOWE_ROOT_DIR
# $INSTALL_DIR
# $LOG_FILE

EXPLORER_API_LIST="jobs-api files-api"

# NOTE FOR DEVELOPMENT
# Use functions _cp/_cpr/_pax to copy/recursive copy/unpax from 
# ${INSTALL_DIR}, as these will mark the source as processed. The build 
# pipeline will verify that all ${INSTALL_DIR} files are processed.
# Use function _cmd to add standard error handling to command execution.
# Use function _setInstallError in custom error handling.

# Note: zowe-install.sh does "chmod 755" for all

_scriptStart zowe-install-explorer-api.sh
#umask 0002

for COMPONENT_ID in ${EXPLORER_API_LIST}; do
  name=${COMPONENT_ID%-*}               # keep until last - (exclusive)
  
  cd ${INSTALL_DIR}
  EXPLORER_API_JAR=$PWD/$(ls -t ./files/${COMPONENT_ID}-server-*.jar | head -1)
  if [ ! -f ${EXPLORER_API_JAR} ]; then
    echo "Error: $script ${name} Explorer API jar (${COMPONENT_ID}-server-*.jar) missing" | tee -a ${LOG_FILE}
    _setInstallError
  else
    EXPLORER_ROOT=${ZOWE_ROOT_DIR}/components/${COMPONENT_ID}
    echo "  Installing ${name} Explorer API into ${EXPLORER_ROOT} ..." >> ${LOG_FILE}
    _cmd mkdir -p ${EXPLORER_ROOT}/bin

    # copy files if mkdir successful
    if [ $? -eq 0 ]; then
      cd ${EXPLORER_ROOT}/bin

      echo "  Copy ${EXPLORER_API_JAR} into ${PWD}" >> ${LOG_FILE}
      _cp $EXPLORER_API_JAR .

      INSTALL_SCRIPT_FOLDER=${INSTALL_DIR}/files/scripts
      EXPLORER_START_SCRIPT=${COMPONENT_ID}-start.sh
      JAR_NAME=$(basename ${EXPLORER_API_JAR})
      echo "  Copy ${INSTALL_SCRIPT_FOLDER}/${COMPONENT_ID}-* into ${PWD}" >> ${LOG_FILE}

      # start script is mandatory
      if [ ! -f ${INSTALL_SCRIPT_FOLDER}/${EXPLORER_START_SCRIPT} ]; then
        echo "Error: $script ${name} Explorer API start script ($EXPLORER_START_SCRIPT) missing" | tee -a ${LOG_FILE}
        _setInstallError
      fi

      # copy all scripts that match ${COMPONENT_ID}
      for longName in $(ls ${INSTALL_SCRIPT_FOLDER}/${COMPONENT_ID}-*); do
        # ${longName} includes path
        shortName=${longName##*-}        # keep from last - (exclusive)          
        _cp ${longName} ./${shortName}
      done

      # start.sh has a reference to the jar which must still be set
      echo "  Updating ${name} Explorer API start script" >> ${LOG_FILE}
      sed -e "s#{{jar_path}}#\${ROOT_DIR}/components/${COMPONENT_ID}/bin/${JAR_NAME}#" \
        ./start.sh > ./updated-start.sh
      _cmd mv ./updated-start.sh ./start.sh

      #chmod -R 755 "${EXPLORER_ROOT}/bin"
    fi    # target dir created
  fi    # jar found
done    # for COMPONENT_ID

_scriptStop
