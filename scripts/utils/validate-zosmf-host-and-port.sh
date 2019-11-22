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
# - ZOSMF_HOST - The IP Address z/OSMF can be reached

# SH: Note - if node is not available then will continue with a warning
if [[ -z "${ZOSMF_HOST}" || -z "${ZOSMF_PORT}" ]]
then 
    . ${ROOT_DIR}/scripts/utils/error.sh "ZOSMF_HOST and ZOSMF_PORT are not both set"
else
  if [ ! -z "$NODE_HOME" ];
  then
    RESPONSE_CODE=`node ${ROOT_DIR}/scripts/utils/zosmfHttpRequest.js ${ZOSMF_HOST} ${ZOSMF_PORT}`
    if [[ -z "${RESPONSE_CODE}" ]]
    then
      echo "Warning: Could not validate if z/OS MF is available on 'https://${ZOSMF_HOST}:${ZOSMF_PORT}/zosmf/info'"
    else
      if [[ $RESPONSE_CODE != 200 ]]
      then
        . ${ROOT_DIR}/scripts/utils/error.sh "Could not contact z/OS MF on 'https://${ZOSMF_HOST}:${ZOSMF_PORT}/zosmf/info' - $RESPONSE_CODE"
      fi
    fi
  else
    echo "Warning: Could not validate if z/OS MF is available on 'https://${ZOSMF_HOST}:${ZOSMF_PORT}/zosmf/info'"
  fi
fi