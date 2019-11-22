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

# Configure and start require:
# - ZOWE_PREFIX + instance - should be <=6 char long and exist
#TODO - any lower bound (other than 0)?
PREFIX_LENGTH=${#ZOWE_PREFIX}
if [[ -z $ZOWE_PREFIX ]]
then
  . ${ROOT_DIR}/scripts/utils/error.sh  "ZOWE_PREFIX is not set"
elif [[ $PREFIX_LENGTH > 6 ]]
then
  . ${ROOT_DIR}/scripts/utils/error.sh  "ZOWE_PREFIX '$ZOWE_PREFIX' should be less than 7 characters"
fi