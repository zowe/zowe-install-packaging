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

# ZOWE_JAVA_HOME Should exist, be version 8+ and be on path
if [[ -n "${ZOWE_JAVA_HOME}" ]]
then 
    ls ${ZOWE_JAVA_HOME}/bin | grep java$ > /dev/null    # pick a file to check
    if [[ $? -ne 0 ]]
    then
        . ${ROOT_DIR}/scripts/utils/error.sh "ZOWE_JAVA_HOME does not point to a valid install of Java"
    else
      JAVA_VERSION=`${ZOWE_JAVA_HOME}/bin/java -version 2>&1 | grep ^"java version"`
      if [[ "$JAVA_VERSION" < "java version \"1.8" ]]
      then 
        . ${ROOT_DIR}/scripts/utils/error.sh "$JAVA_VERSION is less than minimum level required of 1.8"
      fi
    fi
else 
    . ${ROOT_DIR}/scripts/utils/error.sh "ZOWE_JAVA_HOME is empty"
fi
