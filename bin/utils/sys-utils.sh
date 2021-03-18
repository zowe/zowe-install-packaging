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
  sysname=$(sysvar SYSNAME 2>/dev/null)
  if [ -z "${sysname}" ]; then
    sysname=$(hostname -s 2>/dev/null)
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
