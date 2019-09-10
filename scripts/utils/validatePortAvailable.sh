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

# - FILES_API_PORT - should not be bound to a port currently
MATCHES=`onetstat -a | grep -c $1`
if [[ $MATCHES > 0 ]]
then
    . ${ROOT_DIR}/scripts/utils/error.sh "Port $1 is already in use by process `netstat -a -P $1 | grep Listen`"
fi