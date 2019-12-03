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

rc=8

echo "Check if profile ${profile} is defined in class ${class} (SAF=${saf})"

case $saf in

RACF)
  tsocmd "SEARCH CLASS(${class}) FILTER(${profile})" \
    1>/tmp/cmd.out 2>/tmp/cmd.err
  tsoRC=$?
  if [[ $tsoRC -eq 0 ]]
  then
    cat /tmp/cmd.out | grep -F "${profile}" 1>/dev/null
    if [[ $? -eq 0 ]]
    then
      echo "Info: profile ${profile} is defined in class ${class}"
      rc=0
    else
      echo "Warning: profile ${profile} is not defined in class ${class}"
      rc=1
    fi
  elif [[ $tsoRC -eq 4 ]]
  then
    echo "Warning: profile ${profile} is not defined in class ${class}"
    rc=1
  else
    echo Error:  SEARCH failed with the following errors
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  fi
;;

ACF2)
  echo "Warning:  ACF2 support has not been implemented," \
    "please manually check if ${profile} is defined in class ${class}"
  rc=8
;;

TSS)
  if [[ "${class}" = "FACILITY" ]]; then
    class="IBMFAC"
  fi
  tsocmd "TSS WHOOWNS ${class}(${profile})" \
    1>/tmp/cmd.out 2>/tmp/cmd.err
  tsoRC=$?
  if [[ $tsoRC -eq 0 ]]
  then
    # This line converts the facility to an HLQ. e.g, ZWEX.IS becomes ZWEX.
    # For longer HLQs, "ZWEX.DUMMY.HLQ", this returns "ZWEX.DUMMY.". This behavior may not be
    #  desirable in all cases, but is not a risk to current 1.x install which only uses 'ZWEX.IS'.
    # This HLQ facility format is required for TSS, as there may be an HLQ facility definition
    #  with read access granted to a sub-facility.
    profileHlq=$(echo "${profile}" | sed 's/\(.*\.\).*/\1/g')
    cat /tmp/cmd.out | grep -F "${profileHlq}" 1>/dev/null
    if [[ $? -eq 0 ]]
    then
      echo "Info: profile ${profile} is defined in class ${class}"
      rc=0
    else
      echo "Warning: profile ${profile} is not defined in class ${class}"
      rc=1
    fi
  elif [[ $tsoRC -eq 4 ]]
  then
    echo "Warning: profile ${profile} is not defined in class ${class}"
    rc=1
  elif [[ $tsoRC -eq 8 ]]
  then
    tss0318e="TSS0318E  RESOURCE NOT FOUND IN SECURITY FILE"
    cat /tmp/cmd.out | grep -F "${tss0318e}" 1>/dev/null
    if [[ $? -eq 0 ]]; then
      echo "Warning: profile ${profile} is not defined in class ${class}"
      rc=1
    else
      echo Error: WHOOWNS failed with the following errors
      cat /tmp/cmd.out /tmp/cmd.err
      rc=8
    fi
  else # RC > 8
    echo Error:  WHOOWNS failed with the following errors
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

