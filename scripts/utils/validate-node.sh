#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019, 2020
################################################################################

# NODE_HOME Should contain a valid install of Node
if [[ -n "${NODE_HOME}" ]];
then
    ls ${NODE_HOME}/bin | grep node$ > /dev/null
    if [[ $? -ne 0 ]];
    then
        . ${ROOT_DIR}/scripts/utils/error.sh "NODE_HOME: ${NODE_HOME}/bin does not point to a valid install of Node";
    else

      NODE_OK=`${NODE_HOME}/bin/node -e "console.log('ok')" 2>&1`
      if [[ ${NODE_OK} == "ok" ]]
      then
        echo "OK: Node is working"
      else 
        . ${ROOT_DIR}/scripts/utils/error.sh "${NODE_HOME}/bin/node is not functioning correctly: ${NODE_OK}";
      fi

      NODE_MIN_VERSION=6.14
      NODE_VERSION=`${NODE_HOME}/bin/node --version` 
      NODE_VERSION_TRIMMED=`${NODE_HOME}/bin/node --version | sed 's/^.\{1\}//' | cut -d. -f1,2 2>&1`
      if [[ $NODE_VERSION = "v8.16.1" ]];
      then
        . ${ROOT_DIR}/scripts/utils/error.sh "NODE Version 8.16.1 is not compatible with Zowe. Please use a different version. See https://docs.zowe.org/stable/troubleshoot/app-framework/app-known-issues.html#desktop-apps-fail-to-load for more details";
      elif [[ `echo "$NODE_VERSION_TRIMMED $NODE_MIN_VERSION" | awk '{print ($1 < $2)}'` == 1 ]];
      then
        . ${ROOT_DIR}/scripts/utils/error.sh "NODE Version ${NODE_VERSION_TRIMMED} is less than minimum level required of ${NODE_MIN_VERSION}";
      else
        echo "OK: Node is at a supported version"
      fi

    fi
else
    . ${ROOT_DIR}/scripts/utils/error.sh "NODE_HOME is empty";
fi
