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

if [[ ! -d ${DIRECTORY} ]]
then	
  . ${ROOT_DIR}/scripts/utils/error.sh "Directory '${DIRECTORY}' doesn't exist, or is not accessible to ${USERID}. If the directory exists, check all the parent directories have traversal permission (execute)"
  return 1
fi
return 0