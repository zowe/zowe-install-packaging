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

# NODE_HOME Should contain a valid install of Node
if [[ -n "${NODE_HOME}" ]]
then
  ls ${NODE_HOME}/bin | grep node$ > /dev/null
  if [[ $? -ne 0 ]]
  then 
    . ${ROOT_DIR}/scripts/utils/error.sh "NODE_HOM: ${NODE_HOME}/bin does not point to a valid install of Node"
  else
    NODE_OK=`${NODE_HOME}/bin/node -e "console.log('ok')" 2>&1`
    if [[ ! $NODE_OK == "ok" ]]
    then 
      . ${ROOT_DIR}/scripts/utils/error.sh "${NODE_HOME}/bin/node is not functioning correctly"
    fi
  fi
else
  . ${ROOT_DIR}/scripts/utils/error.sh "NODE_HOME is empty"
fi