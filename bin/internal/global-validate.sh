#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

################################################################################
# This script will validate if the environment is well prepared to start Zowe.
################################################################################

checkForErrorsFound() {
  if [[ $ERRORS_FOUND > 0 ]]
  then
      echo "$ERRORS_FOUND errors were found during validatation, please check the message, correct any properties required in ${INSTANCE_DIR}/instance.env and re-launch Zowe"
  fi
}

if [[ "${USER}" == "IZUSVR" ]]
then
  echo "WARNING: You are running the Zowe process under user id IZUSVR. This is not recommended and may impact your z/OS MF server negatively."
fi

# Make sure INSTANCE_DIR is accessible and writable to the user id running this
. ${ROOT_DIR}/scripts/utils/validate-directory-is-writable.sh ${INSTANCE_DIR}
checkForErrorsFound

# Fix node.js piles up in IPC message queue
. ${ROOT_DIR}/scripts/utils/cleanup-ipc-mq.sh

#Temp - whilst desktop components don't have validate scripts
if [[ ${SKIP_NODE} != 1 ]]
then
. ${ROOT_DIR}/scripts/utils/validate-node.sh
checkForErrorsFound
fi

# Validate keystore directory accessible
${ROOT_DIR}/scripts/utils/validate-keystore-directory.sh
checkForErrorsFound
