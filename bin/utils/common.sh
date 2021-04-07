#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020, 2021
################################################################################

print_error_message() {
  message=$1
  #output an error and add to the count
  if [[ -z "${ERRORS_FOUND}" ]];
  then
    ERRORS_FOUND=0
  fi

  # echo error to standard out and err - this was requested so that the errors go into STDOUT of the job
  # and save people going into STDERR (and make it inline with the rest of the logs), but it does result
  # in double outputting when called from shell environment, so maybe we should reconsider?
  echo "Error ${ERRORS_FOUND}: ${message}" 1>&2
  print_message "Error ${ERRORS_FOUND}: ${message}"

  let "ERRORS_FOUND=${ERRORS_FOUND}+1"
}

# In future we can add timestamps/message ids here
print_message() {
  message=$1
  echo "${message}"
}

# If LOG_FILE is an writable file then output to it, otherwise echo instead
log_message() {
  message=$1
  # by default it may also print to stdout, set to false to disable it 
  may_print_to_stdout=$2

  if [[ -n "${LOG_FILE}" ]] && [[ -w "${LOG_FILE}" ]];
  then
    echo ${message} >> $LOG_FILE 
  elif [ "${may_print_to_stdout}" != "false" ]; then
    echo ${message}
  fi
}

# print message to stdout and also write message to log
print_and_log_message() {
  message=$1

  print_message "${message}"
  log_message "${message}" "false"
}

# return current user id
get_user_id() {
  echo ${USER:-${USERNAME:-${LOGNAME}}}
}

get_tmp_dir() {
  echo ${TMPDIR:-${TMP:-/tmp}}
}

# runtime logging functions, follow zowe service logging standard
print_formatted_message() {
  service=$1
  logger=$2
  level=$3
  message=$4

  if [ "${message}" = "-" ]; then
    read message
    if [ -z "${message}" ]; then
      # empty input
      return 0
    fi
  fi

  # always use upper case
  level=$(echo "${level}" | tr '[:lower:]' '[:upper:]')

  # decide if we need to write log based on log level setting ZWE_LOG_LEVEL_<service>
  expected_log_level_var=ZWE_LOG_LEVEL_${service}
  expected_log_level_val=$(eval "echo \${$expected_log_level_var}")
  expected_log_level_val=$(echo "${expected_log_level_val}" | tr '[:lower:]' '[:upper:]')
  if [ -z "${expected_log_level_val}" ]; then
    expected_log_level_val=INFO
  fi
  display_log=false
  case ${expected_log_level_val} in
    ERROR)
      if [ "${level}" = "ERROR" ]; then
        display_log=true
      fi
      ;;
    WARN)
      if [ "${level}" = "ERROR" -o "${level}" = "WARN" ]; then
        display_log=true
      fi
      ;;
    DEBUG)
      if [ "${level}" = "ERROR" -o "${level}" = "WARN" -o "${level}" = "INFO" -o "${level}" = "DEBUG" ]; then
        display_log=true
      fi
      ;;
    TRACE)
      display_log=true
      ;;
    *)
      # INFO
      if [ "${level}" = "ERROR" -o "${level}" = "WARN" -o "${level}" = "INFO" ]; then
        display_log=true
      fi
      ;;
  esac
  if [ "${display_log}" = "false" ]; then
    # no need to display this log based on LOG_LEVEL settings
    return 0
  fi

  log_line_prefix="$(date -u '+%Y-%m-%d %T') <${service}:$$> $(get_user_id) ${level} (${logger})"
  while read -r line; do
    has_prefix=$(echo "$line" | awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/')
    if [ -z "${has_prefix}" ]; then
      line="${log_line_prefix} ${line}"
    fi
    if [ "${level}" = "ERROR" ]; then
      # only errors are written to stderr
      >&2 echo "${line}"
    else
      echo "${line}"
    fi
  done <<EOF
$(echo "${message}")
EOF
}

print_formatted_trace() {
  print_formatted_message "${1}" "${2}" "TRACE" "${3}"
}

print_formatted_debug() {
  print_formatted_message "${1}" "${2}" "DEBUG" "${3}"
}

print_formatted_info() {
  print_formatted_message "${1}" "${2}" "INFO" "${3}"
}

print_formatted_warn() {
  print_formatted_message "${1}" "${2}" "WARN" "${3}"
}

print_formatted_error() {
  print_formatted_message "${1}" "${2}" "ERROR" "${3}"
}

###############################
# Check if there are errors registered
#
# Notes: this function is for Zowe runtime, it requires INSTANCE_DIR variable.
#
# Notes: any error should increase global variable ERRORS_FOUND by 1.
runtime_check_for_validation_errors_found() {
  if [[ ${ERRORS_FOUND} > 0 ]]; then
    print_message "${ERRORS_FOUND} errors were found during validation, please check the message, correct any properties required in ${INSTANCE_DIR}/instance.env and re-launch Zowe"
    if [ ! "${ZWE_IGNORE_VALIDATION_ERRORS}" = "true" ]; then
      exit ${ERRORS_FOUND}
    fi
  fi
}
