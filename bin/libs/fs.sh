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

  parent_absolute_path=$(cd "${parent}" && pwd)
  # find on z/OS USS doesn't support -d
  children=$(cd "${parent_absolute_path}" && ls -1 | sort)
  while read -r child; do
    if [ -d "${parent_absolute_path}/${child}" ]; then
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
  tmpdir=${2:-}

  if [ -z "${tmpdir}" ]; then
    tmpdir=$(get_tmp_dir)
  fi
  while true ; do
    file="${tmpdir}/${prefix}-${RANDOM}"
    if [ ! -f "${file}" ]; then
      echo "${file}"
      break
    fi
  done
}

is_file_accessible() {
  file=$1

  if [ ! -f "${file}" ]; then
    print_error "File '${file}' doesn't exist, or is not accessible to $(get_user_id). If the file exists, check all the parent directories have traversal permission (execute)"
    return 1
  fi
}

is_directory_accessible() {
  directory=$1

  if [ ! -d "${directory}" ]; then
    print_error "Directory '${directory}' doesn't exist, or is not accessible to $(get_user_id). If the directory exists, check all the parent directories have traversal permission (execute)"
    return 1
  fi
}

are_directories_accessible() {
  invalid=0

  for dir in $(echo "${1}" | sed "s/,/ /g"); do
    is_file_accessible "${dir}"
    valid_rc=$?
    if [ ${valid_rc} -ne 0 ]; then
      let "invalid=${invalid}+1"
    fi
  done

  return ${invalid}
}

is_directory_writable() {
  directory=$1

  is_directory_accessible "${directory}"
  accessible_rc=$?
  if [ ${accessible_rc} -ne 0 ]; then
    return ${accessible_rc}
  fi
  if [ ! -w "${directory}" ]; then
    print_error "Directory '${directory}' does not have write access"
    return 1
  fi
}
