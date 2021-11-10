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

# return current user id
get_user_id() {
  echo ${USER:-${USERNAME:-${LOGNAME:-$(whoami 2>/dev/null)}}}
}

get_tmp_dir() {
  echo ${TMPDIR:-${TMP:-/tmp}}
}

print_raw_message() {
  message=$1
  is_error=$2
  # can be combination of log and/or console
  write_to=$3

  if [ -z "${write_to}" ]; then
    # default to write to both
    write_to=console,log
  fi

  if [[ "${write_to}" = *console* ]]; then
    if [ "${is_error}" = "true" ]; then
      >&2 echo "${message}"
    else
      echo "${message}"
    fi
  fi
  if [[ "${write_to}" = *log* ]]; then
    if [ -n "${ZOWE_LOG_FILE}" -a -w "${ZOWE_LOG_FILE}" ]; then
      echo "${message}" >> $ZOWE_LOG_FILE
    fi
  fi
}

print_message() {
  message=$1
  # can be combination of log and/or console
  write_to=$2

  print_raw_message "${message}" "false" "${write_to}"
}

print_error() {
  message=$1
  # can be combination of log and/or console
  write_to=$2

  print_raw_message "${message}" "true" "${write_to}"
}

print_error_and_exit() {
  message=$1
  # can be combination of log and/or console
  write_to=$2
  exit_code=$3

  if [ -z "${exit_code}" ]; then
    exit_code=1
  fi

  print_error "${message}" "${write_to}"
  exit ${exit_code}
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

  # reset values
  export service=
  export logger=
  export level=
  export message=
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
