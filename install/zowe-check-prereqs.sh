#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2020
################################################################################

# Verify that the Zowe pre-reqs are in place before you install Zowe on z/OS

export UNPAX_DIR=$(cd $(dirname $0)/../;pwd)

echo Script zowe-check-prereqs.sh started

echo
echo Checking opercmd availability...

# Note: opercmd requires SDSF
OPERCMD=${UNPAX_DIR}/scripts/opercmd
if [[ -r ${OPERCMD} ]]
then 
  chmod u+x ${OPERCMD}
  if [[ $? -ne 0 ]]
  then
    echo Error:  Unable to make opercmd executable
    OPERCMD=""
  else 
    ${OPERCMD} "d t" 1> /dev/null 2> /dev/null  # is 'opercmd' available and working?
    if [[ $? -ne 0 ]]
    then
      echo Error: Unable to run opercmd REXX exec from ls -l ${OPERCMD} # try to list opercmd
      echo Warning: z/OS release will not be checked
      OPERCMD=""
    else
      echo OK: opercmd is available
    fi
  fi 
else 
  echo Error: Cannot access opercmd
  OPERCMD=""
fi 

# z/OS UNIX System Services enabled, and 
# Integrated Cryptographic Service Facility (ICSF) configured and started.

if [[ -z ${OPERCMD} ]]
then
  echo
  echo Warning: Cannot access opercmd, so ICSF will not be checked
else
  echo
  echo Checking ICSF or CSF...  # required for node commands
  ICSF=0  # no active job
  for jobname in ICSF CSF # jobname will be one or the other
  do
    ${OPERCMD} d j,${jobname}|grep " ${jobname} .* A=[0-9,A-F][0-9,A-F][0-9,A-F][0-9,A-F] " > /dev/null
    if [[ $? -eq 0 ]]
    then
      ICSF=1  # found job active
      break
    fi
  done
  if [[ $ICSF -eq 1 ]]
  then 
    echo OK: jobname ICSF or CSF is running
  else
    echo Error: jobname ICSF or CSF is not running
  fi
fi

# Check Node is installed, working and the version is compatible
echo
echo Checking Node version...

export ROOT_DIR=${UNPAX_DIR} #Set root so the utils scripts can work
. ${ROOT_DIR}/bin/utils/node-utils.sh
if [[ -z ${NODE_HOME} ]]
then
  prompt_for_node_home_if_required
fi

. ${UNPAX_DIR}/bin/internal/zowe-set-env.sh
ensure_node_is_on_path 1> /dev/null
validate_node_home

echo Script zowe-check-prereqs.sh ended