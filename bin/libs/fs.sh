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
# Note: the result is sorted in alphabetical sequence.
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

# Takes in the file that should be expanded and echos out the result, which the caller needs to read
convert_to_absolute_path() {
  file=$1

  # If the value starts with a ~ for the home variable then evaluate it
  file=$(echo "${file}")

  # If the path is relative, then expand it
  if [[ "${file}" != /* ]]; then
    file="$(pwd)/${file}"
  fi

  echo "${file}"
}

get_tmp_dir() {
  echo ${TMPDIR:-${TMP:-/tmp}}
}

create_tmp_file() {
  prefix=${1:-zwe}

  tmpdir=$(get_tmp_dir)
  while true ; do
    file="${tmpdir}/${prefix}-${RANDOM}"
    if [ ! -f "${file}" ]; then
      echo "${file}"
      break
    fi
  done
}
