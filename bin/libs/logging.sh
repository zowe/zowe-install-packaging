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

export ZWE_PRIVATE_LOG_FILE=

prepare_log_file() {
  if [ -f "${1}" ]; then
    print_error_and_exit "Error ZWEL0102E: Invalid parameter --log-dir=${1} (not a directory)" "" 102
  fi
  # use absolute path to make sure we can always write to correct location even
  # if other scripts changed current working directory
  log_dir=$(convert_to_absolute_path "${1}" | remove_trailing_slash)
  log_file_prefix="${2}"

  ZWE_PRIVATE_LOG_FILE="${log_dir}/${log_file_prefix}-$(date +%Y%m%dT%H%M%S).log"
  if [ ! -f "${ZWE_PRIVATE_LOG_FILE}" ]; then
    # create and echo message if log file doesn't exist
    mkdir -p "${log_dir}"
    if [ ! -w "${log_dir}" ]; then
      print_error_and_exit "Error ZWEL0110E: Doesn't have write permission on ${1} directory." "" 110
    fi
    touch ${ZWE_PRIVATE_LOG_FILE}
    print_debug "Log file created: ${ZWE_PRIVATE_LOG_FILE}" "console"
  fi
  chmod a+rw ${ZWE_PRIVATE_LOG_FILE}
}
