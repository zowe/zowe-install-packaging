#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019
################################################################################

# - ZOSMF_PORT - The SSL port z/OSMF is listening on.
# - ZOSMF_IP_ADDRESS - The IP Address z/OSMF can be reached

# SH: Note - if node is not available then will continue with a warning
if [[ -z "${ZOSMF_IP_ADDRESS}" || -z "${ZOSMF_PORT}" ]]
then 
    . ${ZOWE_ROOT_DIR}/scripts/utils/error.sh "ZOSMF_IP_ADDRESS and ZOSMF_PORT are not both set"
else
  if [ ! -z "$NODE_HOME" ];
  then
    NODE_BIN=${NODE_HOME}/bin/node
    RESPONSE_CODE=`$NODE_BIN httpRequest.js ${ZOSMF_IP_ADDRESS} ${ZOSMF_PORT}`
    if [[ -z "${RESPONSE_CODE}" ]]
    then
      echo "Warning: Could not validate if z/OS MF is available on 'https://${ZOSMF_IP_ADDRESS}:${ZOSMF_PORT}/zosmf/info'"
    else
      if [[ $RESPONSE_CODE != 200 ]]
      then
        . ${ZOWE_ROOT_DIR}/scripts/utils/error.sh "Could not contact z/OS MF on 'https://${ZOSMF_IP_ADDRESS}:${ZOSMF_PORT}/zosmf/info' - $RESPONSE_CODE"
      fi
    fi
  else
    echo "Warning: Could not validate if z/OS MF is available on 'https://${ZOSMF_IP_ADDRESS}:${ZOSMF_PORT}/zosmf/info'"
  fi
fi