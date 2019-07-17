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
profile=$2
user=$3

rc=8

echo "Grant user ${user} READ access to profile ${profile} in the FACILITY class (SAF=${saf})"

case $saf in

RACF) 
  tsocmd "PERMIT ${profile} CLASS(FACILITY) ID(${user}) ACCESS(READ)" \
    1> /tmp/cmd.out 2> /tmp/cmd.err 
  if [[ $? -ne 0 ]]
  then
    echo Error: PERMIT failed with the following errors
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  else
    tsocmd "SETROPTS REFRESH RACLIST(FACILITY)" \
      1> /tmp/cmd.out 2> /tmp/cmd.err
    echo "Info:  access has been granted"
    rc=0
  fi
;;

ACF2)
  echo "Warning:  ACF2 support has not been implemented," \
    "please manually grant user ${user} READ access to ${profile} in the FACILITY class"
  rc=8
;;

TSS)
  tsocmd "TSS PERMIT(${user}) IBMFAC(${profile}) ACCESS(READ)" \
    1>/tmp/cmd.out 2>/tmp/cmd.err
  tsoRC=$?
  tss0300="TSS0300I  PERMIT   FUNCTION SUCCESSFUL"

  if [[ $tsoRC -eq 0 ]]
  then
    cat /tmp/cmd.out | grep -F "${tss0300}" 1>/dev/null
    if [[ $? -eq 0 ]]
    then
      echo "Info: User ${user} was granted READ access to ${profile}."
      rc=0
    else
      rc=8
    fi
  fi
  if [[ $rc -ne 0 ]]; then
    echo "Error:  PERMIT function failed with the following errors:"
    cat /tmp/cmd.out /tmp/cmd.err
  fi
  ;;

*)
  echo "Error:  Unexpected SAF $saf"
  rc=8
esac

rm /tmp/cmd.out /tmp/cmd.err 1> /dev/null 2> /dev/null
return $rc

