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

###############################
# Return system name in lower case
#
# - value &SYSNAME variable
# - short hostname
get_sysname() {
  # works for z/OS
  sysname=$(sysvar SYSNAME 2>/dev/null)
  if [ -z "${sysname}" ]; then
    # works for z/OS and most Linux with hostname command
    sysname=$(hostname -s 2>/dev/null)
  fi
  if [ -z "${sysname}" ]; then
    # we are in container
    if [ -n "${ZOWE_COMPONENT_ID}" ]; then
      # works for Kubernetes containers
      sysname=$(cat /etc/hosts | grep "${ZOWE_COMPONENT_ID}" | head -1 | awk '{print $2}')
    fi
    if [ -z "${sysname}" ]; then
      # this could be a wild guess for container, check the last entry of /etc/hosts
      # works for containers not running in Kubernetes, and Linux without hostname command, like ubi-minimal
      sysname=$(cat /etc/hosts | tail -1 | awk '{print $2}')
    fi
  fi
  echo "${sysname}" | tr '[:upper:]' '[:lower:]'
}

###############################
# Check if script is running on z/OS
#
# Output          true if it's z/OS
is_on_zos() {
  if [ `uname` = "OS/390" ]; then
    echo "true"
  fi
}
