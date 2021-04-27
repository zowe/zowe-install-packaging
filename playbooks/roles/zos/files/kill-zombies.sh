#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2021
################################################################################

curr_pwd=$(pwd)
owner=${1:-ZWESVUSR}
zombies=$("${curr_pwd}/opercmd.rexx" "D OMVS,U=${owner}" | grep "${owner}" | grep -v OMVS | grep -v "NOT FOUND")
count=0
echo "${zombies}" | while read line ; do
  jobname=$(echo "${line}" | awk '{print $2}')
  asid=$(echo "${line}" | awk '{print $3}')
  if [ "${jobname}" = '0000' -o -z "${jobname}" ]; then
    continue
  fi

  count=`expr $count + 1`
  echo "Cancelling ${jobname},ASID=${asid}"
  "${curr_pwd}/opercmd.rexx" "C ${jobname},A=${asid}"
done
echo "${count} zombie(s) killed"
