#!/bin/sh

# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
# 
# SPDX-License-Identifier: EPL-2.0
# 
# Copyright Contributors to the Zowe Project.

BASEDIR=$(dirname "$0")
dsn=$1

echo "Check if $dsn exists"

lastcc=`tsocmd "listcat entries('$dsn')" 2>/dev/null | sed -n "s/.*LASTCC=\([0-9]*\).*/\1/p"`
if [[ -z "$lastcc" ]]
then
  echo "Info:  dataset $dsn exists"
  return 1
else
  echo "Info:  dataset $dsn doesn't exit"
  return 0
fi

