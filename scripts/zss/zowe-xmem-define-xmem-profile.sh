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

rc=8

echo "Define cross-memory server profile ${profile} (SAF=${saf})"

case $saf in

RACF) 
  tsocmd "RDEFINE FACILITY ${profile} UACC(NONE)" \
    1> /tmp/cmd.out 2> /tmp/cmd.err 
  if [[ $? -ne 0 ]]
  then
    echo Error:  RDEFINE failed with the following errors
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  else
    tsocmd "SETROPTS REFRESH RACLIST(FACILITY)" \
      1> /tmp/cmd.out 2> /tmp/cmd.err
    echo "Info:  profile has been defined"
    rc=0
  fi
;;

ACF2)
  echo "Warning:  ACF2 support has not been implemented," \
    "please manually create ${profile} in the FACILITY class with UACC(NONE)"
  rc=8
;;

TSS)
  tsocmd "TSS ADDTO(IZUSVR) IBMFAC(${profile})" \
    1> /tmp/cmd.out 2> /tmp/cmd.err
  if [[ $? -ne 0 ]]
  then
    echo "Error:  TSS ADD IBMFAC(${profile}) failed with the following errors: "
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  else
    echo "Info:  IBMFAC(${profile}) has been defined to IZUSVR"
    rc=0
  fi
;;

*)
  echo "Error:  Unexpected SAF $saf"
  rc=8
esac

rm /tmp/cmd.out /tmp/cmd.err 1> /dev/null 2> /dev/null
exit $rc

