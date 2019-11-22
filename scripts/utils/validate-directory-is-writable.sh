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

DIRECTORY=$1
USERID=`whoami`

$(. . ${ROOT_DIR}/scripts/utils/validate-directory-is-accessible.sh)
AUTH_RETURN_CODE=$?
if [[ $AUTH_RETURN_CODE == "0" ]];
then	
	if [[ ! -w ${DIRECTORY} ]]
	then	
	  . ${ROOT_DIR}/scripts/utils/error.sh "Directory '${DIRECTORY}' does not have write access"	
	fi
fi