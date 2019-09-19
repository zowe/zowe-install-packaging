#!/bin/sh

# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
# 
# SPDX-License-Identifier: EPL-2.0
# 
# Copyright Contributors to the Zowe Project.

BASEDIR=$(dirname "$0")
OPERCMD=$1
loadlib=$2

echo "APF-authorize loadlib ${loadlib}"

isSMS=true
sh $BASEDIR/zowe-xmem-check-if-sms.sh ${loadlib}
checkRC=$?
if [[ $checkRC -eq 1 ]]; then
  isSMS=true
elif [[ $checkRC -eq 0 ]]; then
  isSMS=false
else
  echo "Warning:  SMS check failed, please APF-authorize the dataset manually if needed"
fi

if $isSMS ; then

  cmdout="$(${OPERCMD} "SETPROG APF,ADD,DSNAME=${loadlib},SMS" 2>&1)"

else

  cmdout="$(tsocmd "listds '${loadlib}'" 2>&1)"
  if [[ $? -ne 0 ]]; then
    echo "Error:  LISTDS failed"
    echo "$cmdout"
    exit 8
  fi

  volume="$(echo $cmdout | sed -n "s/.*--VOLUMES--[\s]*\([^\s]\)[\s]*/\1/p")"
  if [[ -z "$volume" ]]; then
    echo "Error:  volume not found"
    echo "$cmdout"
    exit 8
  fi

  cmdout="$(${OPERCMD} "SETPROG APF,ADD,DSNAME=${loadlib},VOLUME=${volume}" 2>&1)"

fi

if echo $cmdout | grep "CSV410I" 1>/dev/null; then
  echo "Info:  dataset ${loadlib} has been added to APF list"
  exit 0
else
  echo "Error:  dataset ${loadlib} has not been added to APF list"
  echo "$cmdout"
  exit 8
fi

