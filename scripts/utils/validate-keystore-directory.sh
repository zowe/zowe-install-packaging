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

$(. ${ROOT_DIR}/scripts/utils/validate-directory-is-accessible.sh ${KEYSTORE_DIRECTORY})
RETURN_CODE=$?
if [[ $RETURN_CODE != "0" ]];
then
  . ${ROOT_DIR}/scripts/utils/error.sh "Was <root-dir>/bin/zowe-setup-certificates.sh run, or KEYSTORE_DIRECTORY property updated in instance.env? See docs for more details"
fi