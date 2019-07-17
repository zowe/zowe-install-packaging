#!/bin/sh

# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
# 
# SPDX-License-Identifier: EPL-2.0
# 
# Copyright Contributors to the Zowe Project.

saf=$1
prefix=$2
profile=$prefix"*.*"

echo "Check STC profile ${profile} (SAF=${saf})"

case $saf in

RACF)
  sh ${SCRIPT_DIR}/zowe-xmem-check-profile.sh $saf STARTED $profile
;;

ACF2)
  echo "Warning:  ACF2 support has not been implemented," \
    "please manually check if ${profile} is defined as an STC in ACF2"
  rc=8
;;

TSS)
  tsocmd "TSS LIST(STC) PROCNAME(${prefix})PREFIX" \
    1>/tmp/cmd.out 2>/tmp/cmd.err
  tsoRC=$?
  if [[ $tsoRC -eq 0 ]]
  then
    cat /tmp/cmd.out | grep -F "${prefix}" 1>/dev/null
    if [[ $? -eq 0 ]]
    then
      echo "Info: STC with prefix \"${prefix}\" is defined in TSS"
      rc=0
    else
      echo "Warning: STC with prefix \"${prefix}\" is not defined to TSS"
      rc=1
    fi
  elif [[ $tsoRC -eq 4 ]]
  then
    echo "Warning: STC with prefix \"${prefix}\" is not defined to TSS"
    rc=1
  else
    echo "Error:  LIST(STC) failed with the following errors"
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  fi
;;

*)
  echo "Error:  Unexpected SAF $saf"
  rc=8
esac

rm /tmp/cmd.out /tmp/cmd.err 1> /dev/null 2> /dev/null
exit $rc

