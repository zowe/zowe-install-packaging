#!/bin/sh

# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
# 
# SPDX-License-Identifier: EPL-2.0
# 
# Copyright Contributors to the Zowe Project.

BASEDIR=$(dirname "$0")
loadlib=$1

echo "APF-authorize loadlib ${loadlib}"

if $BASEDIR/../opercmd "SETPROG APF,ADD,DSNAME=${loadlib},SMS" | grep "CSV410I" 1>/dev/null; then
  echo "Info:  dataset ${loadlib} has been added to APF list"
  exit 0
else
  echo "Error:  dataset ${loadlib} has not been added to APF list"
  exit 8
fi

