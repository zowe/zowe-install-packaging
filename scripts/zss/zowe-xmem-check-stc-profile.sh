#!/bin/sh

# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
# 
# SPDX-License-Identifier: EPL-2.0
# 
# Copyright Contributors to the Zowe Project.

BASEDIR=$(dirname "$0")
saf=$1
prefix=$2
profile=$prefix"*.*"

echo "Check STC profile ${profile} (SAF=${saf})"

sh $BASEDIR/zowe-xmem-check-profile.sh $saf STARTED $profile

exit $?

