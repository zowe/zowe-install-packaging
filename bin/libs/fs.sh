#!/bin/sh

#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

###############################
# List all first level child directories
#
# Note: the result is sorted.
#
# @param string   Path to parent directory
find_sub_directories() {
  parent=$1

  # find on z/OS USS doesn't support -d
  children=$(ls -1 "${parent}" | sort)
  while read -r child; do
    if [ -d "${parent}/${child}" ]; then
      echo "${child}"
    fi
  done <<EOF
$(echo "${children}")
EOF
}
