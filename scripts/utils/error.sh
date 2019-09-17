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

#output an error and add to the count

if [ -z "$ERRORS_FOUND" ];
then
  ERRORS_FOUND=0
fi

echo "Error $ERRORS_FOUND: $1"
let "ERRORS_FOUND=$ERRORS_FOUND+1"
