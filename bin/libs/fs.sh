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
  parent="${1}"

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

convert_to_absolute_path() {
    # generate absolute path from relative path
    # $1     : relative filename
    # return : absolute path
    orgPath="${1}"
    if [ -d "$orgPath" ]; then
        if [[ $orgPath = /* ]]; then
            echo "$orgPath"
        else
            (cd "$orgPath"; pwd)
        fi
    elif  [ -f "$orgPath" ]; then
        # file
        if [[ $orgPath = /* ]]; then
            echo "$orgPath"
        elif [[ $orgPath == */* ]]; then
            echo "$(cd "${orgPath%/*}"; pwd)/${orgPath##*/}"
        else
            echo "$(pwd)/$orgPath"
        fi
    else
        echo "$orgPath"
    fi
}

get_tmp_dir() {
  print_debug ">> Check if either TMPDIR or TMP points to writable directory, else try \"/tmp\" directory"
  tmpdir="${TMPDIR:-${TMP:-/tmp}}"
  is_directory_writable "${tmpdir}"
  if [ $? -ne 0 ]; then
    print_error "Error ZWEL0110E: Doesn't have write permission on ${tmpdir} directory"
    exit 110
  else
    echo "${tmpdir}"
  fi
}

create_tmp_file() {
  prefix=${1:-zwe}
  tmpdir=${2:-}

  if [ -z "${tmpdir}" ]; then
    tmpdir=$(get_tmp_dir)
  fi
  print_trace "  > create_tmp_file on ${tmpdir}"
  last_rnd=
  idx_retry=0
  max_retry=100
  while true ; do
    if [ ${idx_retry} -gt ${max_retry} ]; then
      print_error "    - Error ZWEL0114E: Reached max retries on allocating random number."
      exit 114
      break
    fi

    rnd=$(echo "${RANDOM}")
    if [ "${rnd}" = "${last_rnd}" ]; then
      # reset random
      RANDOM=$(date '+1%H%M%S')
    fi

    file="${tmpdir}/${prefix}-${rnd}"
    print_trace "    - test ${file}"
    if [ ! -e "${file}" ]; then
      print_trace "    - good"
      echo "${file}"
      break
    fi

    last_rnd="${rnd}"
    idx_retry=`expr $idx_retry + 1`
  done
}

###############################
# Copies dataset to Unix file
#
#
# @param string   Dataset name
# @param string   Unix file name
copy_mvs_to_uss() {
  cp "//'$1'" "$2"
  return $?
}

is_file_accessible() {
  file="${1}"

  if [ ! -f "${file}" ]; then
    print_error "File '${file}' doesn't exist, or is not accessible to $(get_user_id). If the file exists, check all the parent directories have traversal permission (execute)"
    return 1
  fi
}

is_directory_accessible() {
  directory="${1}"

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
  directory="${1}"

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

are_directories_same() {
  dir1="${1}"
  dir2="${2}"

  abs_dir1=$(cd "${dir1}" && pwd)
  abs_dir2=$(cd "${dir2}" && pwd)

  if [ "${abs_dir1}" = "${abs_dir2}" ]; then
    return 0
  else
    return 1
  fi
}
