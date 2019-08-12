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
saf=$2
stcUser=$3
uid=$4
stcGroup=$5

rc=8

echo "Define STC user ${stcUser} with UID=${uid} and GROUP=${stcGroup} (SAF=${saf})"

case $saf in

RACF)
  tsocmd "ADDUSER ${stcUser} DFLTGRP(${stcGroup}) OMVS(UID(${uid})) AUTHORITY(USE)" \
    1>/tmp/cmd.out 2>/tmp/cmd.err
  if [[ $? -eq 0 ]]
  then
    echo "Info:  User ${stcUser} has been added"
    rc=0
  else
    echo "Error:  User ${stcUser} has not been added"
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  fi
  ;;

ACF2)
  tsocmd "INSERT ${stcUser} GROUP(${stcGroup}) SET PROFILE(USER) DIV(OMVS) INSERT ${stcUser} UID(${stcUser})" \
    1>/tmp/cmd.out 2>/tmp/cmd.err
  if [[ $? -eq 0 ]]
  then

    ${OPERCMD} "F ACF2,REBUILD(USR),CLASS(P)" 1> /dev/null 2> /dev/null \
      1> /tmp/cmd.out 2> /tmp/cmd.err
    if [[ $? -ne 0 ]]
    then
      echo "Error: ACF2 REBUILD failed with the following errors"
      cat /tmp/cmd.out /tmp/cmd.err
      rc=8
    fi

    ${OPERCMD} "F ACF2,OMVS" 1> /dev/null 2> /dev/null \
      1> /tmp/cmd.out 2> /tmp/cmd.err
    if [[ $? -ne 0 ]]
    then
      echo "Error: ACF2 OMVS failed with the following errors"
      cat /tmp/cmd.out /tmp/cmd.err
      rc=8
    fi

    echo "Info:  User ${stcUser} has been added"
    rc=0
  else
    echo "Error:  User ${stcUser} has not been added"
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  fi
  ;;

TSS)
  tsocmd "TSS ADDTO(${stcUser}) DFLTGRP(${stcGroup}) UID(${uid})" \
    1>/tmp/cmd.out 2>/tmp/cmd.err
  if [[ $? -eq 0 ]]
  then
    echo "Info:  Group ${stcGroup} and UID ${uid} have been added to User ${stcUser}"
    rc=0
  else
    echo "Error:  Group ${stcGroup} and UID ${uid} were not added to User ${stcUser}"
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  fi
  ;;

*)
  echo "Error: Unexpected SAF $saf"
  rc=8
esac

rm /tmp/cmd.out /tmp/cmd.err 1> /dev/null 2> /dev/null
exit $rc

