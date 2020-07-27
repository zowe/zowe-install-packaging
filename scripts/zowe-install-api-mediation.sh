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

# NOTE FOR DEVELOPMENT
# Use functions _cp/_cpr/_pax to copy/recursive copy/unpax from 
# ${INSTALL_DIR}, as these will mark the source as processed. The build 
# pipeline will verify that all ${INSTALL_DIR} files are processed.
# Use function _cmd to add standard error handling to command execution.
# Use function _setInstallError in custom error handling.

# Note: zowe-install.sh does "chmod 755" for all

_scriptStart zowe-install-api-mediation.sh
#umask 0002

cd $INSTALL_DIR
API_MEDIATION_PAX=$PWD/$(ls -t ./files/api-mediation-package*.pax | head -1)
if [ ! -f ${API_MEDIATION_PAX} ]; then
  echo "Error: $script API Mediation archive (api-mediation-package*.pax) missing" | tee -a ${LOG_FILE}
  _setInstallError
else
  API_MEDIATION_ROOT=${ZOWE_ROOT_DIR}/components/api-mediation
  echo "  Installing API Mediation into ${API_MEDIATION_ROOT} ..." >> ${LOG_FILE}
  _cmd mkdir -p ${API_MEDIATION_ROOT}

  # unpax archive if mkdir successful
  if [ $? -eq 0 ]; then
    cd ${API_MEDIATION_ROOT}
    echo "  Unpax of ${API_MEDIATION_PAX} into ${PWD}" >> ${LOG_FILE}
    _pax $API_MEDIATION_PAX

    # additional tasks if unpax successful
    if [ $? -eq 0 ]; then
      # nop
    fi    # unpax successful
  fi    # target dir created
fi    # pax found

#chmod a+rx "${API_MEDIATION_DIR}"/*.jar 
#chmod -R 751 "${API_MEDIATION_DIR}/bin"
#chmod -R 751 "${API_MEDIATION_DIR}/assets"

_scriptStop
