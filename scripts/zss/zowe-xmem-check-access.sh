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
class=$2
profile=$3
user=$4

rc=8

echo "Check if user ${user} has access to profile ${profile} in class ${class} (SAF=${saf})"

case $saf in

RACF)
  tsocmd "SEARCH CLASS(${class}) FILTER(${profile}) USER(${user})" \
    1>/tmp/cmd.out 2>/tmp/cmd.err
  tsoRC=$?
  if [[ $tsoRC -eq 0 ]]
  then
    echo "Info: user ${user} has access to ${profile} in class ${class}"
    rc=0
  elif [[ $tsoRC -eq 4 ]]
  then
    echo "Warning: user ${user} has no access to ${profile} in class ${class}"
    rc=1
  else
    echo Error:  SEARCH failed with the following errors
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  fi
;;

ACF2)
  echo "Warning:  ACF2 support has not been implemented," \
    "please manually check if ${user} has access"
  rc=8
;;

TSS)
  if [[ "${class}" = "FACILITY" ]]; then
    class="IBMFAC"
  fi
  tsocmd "TSS WHOHAS ${class}(${profile})" \
    1>/tmp/cmd.out 2>/tmp/cmd.err
  tsoRC=$?
  if [[ $tsoRC -eq 0 ]]
  then
    cat /tmp/cmd.out | grep -F "${user}" 1>/dev/null
    if [[ $? -eq 0 ]]
    then
      echo "Info: user ${user} has access to ${profile} in class ${class}"
      rc=0
    else
      echo "Warning: user ${user} has no access to ${profile} in class ${class}"
      rc=1
    fi
  elif [[ $tsoRC -eq 4 ]]
  then
    echo "Warning: user ${user} has no access to ${profile} in class ${class}"
    rc=1
  else
    echo Error:  WHOHAS failed with the following errors
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  fi
;;

*)
  echo "Error:  Unexpected SAF $saf"
  rc=8
esac

rm /tmp/cmd.out /tmp/cmd.err 1> /dev/null 2> /dev/null
return $rc
