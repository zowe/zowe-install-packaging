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

# $1 - should not be bound to a port currently
PORT=$1
MATCHES=`onetstat -P $PORT | grep -c $PORT`
if [[ $MATCHES > 0 ]]
then
    . ${ROOT_DIR}/scripts/utils/error.sh "Port $PORT is already in use by process `onetstat -P $PORT | grep Listen`"
fi