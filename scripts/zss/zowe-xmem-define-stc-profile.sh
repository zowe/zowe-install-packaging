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
stcPrefix=$2
stcUser=$3
stcGroup=$4

rc=8

echo "Define STC prefix ${stcPrefix} with STC user ${stcUser} and GROUP=${stcGroup} (SAF=${saf})"

case $saf in

RACF) 
  tsocmd "RDEFINE STARTED ${stcPrefix}*.* UACC(NONE) STDATA(USER(${stcUser}) GROUP(${stcGroup}))" \
    1> /tmp/cmd.out 2> /tmp/cmd.err 
  if [[ $? -ne 0 ]]
  then
    echo Error:  RDEFINE failed with the following errors
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  else
    tsocmd "SETROPTS REFRESH RACLIST(STARTED)" \
      1> /tmp/cmd.out 2> /tmp/cmd.err
    echo "Info:  STC profile has been defined"
    rc=0
  fi
  ;;

ACF2)
  tsocmd "SET CONTROL(GSO)" \
    1> /tmp/cmd.out 2> /tmp/cmd.err 
  if [[ $? -ne 0 ]]
  then
    echo "Error:  SET CONTROL(GSO) failed with the following errors"
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  else
    tsocmd "INSERT STC.${stcPrefix}***** LOGONID(${stcUser}) GROUP(${stcGroup}) STCID(${stcPrefix}*****)" \
      1> /tmp/cmd.out 2> /tmp/cmd.err 
    if [[ $? -ne 0 ]]
    then
      echo "Error:  INSERT STC failed with the following errors"
      cat /tmp/cmd.out /tmp/cmd.err
      rc=8
    else
      $BASEDIR/../opercmd "F ACF2,REFRESH(STC)" 1> /dev/null 2> /dev/null \
        1> /tmp/cmd.out 2> /tmp/cmd.err 
      if [[ $? -ne 0 ]]
      then
        echo "Error:  ACF2 REFRESH failed with the following errors"
        cat /tmp/cmd.out /tmp/cmd.err
        rc=8
      else
        echo "Info:  STC profile has been defined"
        rc=0
      fi
    fi
  fi            
  ;;

TSS)
  tsocmd "TSS ADD(${stcUser}) PROFILE(${stcGroup})" \
    1> /tmp/cmd.out 2> /tmp/cmd.err 
  if [[ $? -ne 0 ]]
  then
    echo "Error:  TSS ADDTO(${stcUser}) PROFILE(${stcGroup}) failed with the following errors"
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  else
    echo "Info:  STC profile ${stcGroup} has been added to ${stcUser}"
    rc=0
  fi 
  ;;

*)
  echo "Error:  Unexpected SAF $saf"
  rc=8
esac

rm /tmp/cmd.out /tmp/cmd.err 1> /dev/null 2> /dev/null
exit $rc

