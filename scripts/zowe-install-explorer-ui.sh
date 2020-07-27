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

UI_PLUGIN_LIST="jes mvs uss"

# NOTE FOR DEVELOPMENT
# Use functions _cp/_cpr/_pax to copy/recursive copy/unpax from 
# ${INSTALL_DIR}, as these will mark the source as processed. The build 
# pipeline will verify that all ${INSTALL_DIR} files are processed.
# Use function _cmd to add standard error handling to command execution.
# Use function _setInstallError in custom error handling.

# Note: zowe-install.sh does "chmod 755" for all

_scriptStart zowe-install-explorer-ui.sh
#umask 0002

for COMPONENT_ID in ${UI_PLUGIN_LIST}; do
  UPPERCASE=$(echo ${COMPONENT_ID} | tr '[[:lower:]]' '[[:upper:]]')

  cd ${INSTALL_DIR}
  EXPLORER_PLUGIN_PAX=$PWD/$(ls -t ./files/explorer-${COMPONENT_ID}-*.pax | head -1)
  if [ ! -f ${EXPLORER_PLUGIN_PAX} ]; then
    echo "Error: $script ${UPPERCASE} Explorer UI archive (explorer-${COMPONENT_ID}-*.pax) missing" | tee -a ${LOG_FILE}
    _setInstallError
  else
    EXPLORER_ROOT=${ZOWE_ROOT_DIR}/components/explorer-${COMPONENT_ID}
    echo "  Installing ${UPPERCASE} Explorer UI into ${EXPLORER_ROOT} ..." >> ${LOG_FILE}
    _cmd mkdir -p ${EXPLORER_ROOT}/bin

    # unpax archive if mkdir successful
    if [ $? -eq 0 ]; then
      cd ${EXPLORER_ROOT}/bin
      echo "  Unpax of ${EXPLORER_PLUGIN_PAX} into ${PWD}" >> ${LOG_FILE}
      _pax ${EXPLORER_PLUGIN_PAX}

      # copy scripts if unpax successful
      if [ $? -eq 0 ]; then
        INSTALL_SCRIPT_FOLDER=${EXPLORER_ROOT}/bin/scripts
        EXPLORER_START_SCRIPT=explorer-${COMPONENT_ID}-start.sh
        echo "  Copy ${INSTALL_SCRIPT_FOLDER}/* into ${PWD}" >> ${LOG_FILE}

        # start script is mandatory
        if [ ! -f ${INSTALL_SCRIPT_FOLDER}/${EXPLORER_START_SCRIPT} ]; then
          echo "Error: $script ${UPPERCASE} Explorer UI start script ($EXPLORER_START_SCRIPT) missing" | tee -a ${LOG_FILE}
          _setInstallError
        fi

        # move all scripts
        for longName in $(ls ${INSTALL_SCRIPT_FOLDER}/*); do
          # ${longName} includes path
          shortName=${longName##*-}      # keep from last - (exclusive)
          _cmd mv ${longName} ./${shortName}
        done

        # cleanup, this was created by pax and is empty now
        rm -rf ${INSTALL_SCRIPT_FOLDER}

        #chmod -R 755 ${EXPLORER_ROOT}/bin
      fi    # unpax successful
    fi    # target dir created
  fi    # pax found
done    # for COMPONENT_ID

_scriptStop
