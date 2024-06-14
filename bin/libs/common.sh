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

# these are shell environments we want to enforce in all cases
export _CEE_RUNOPTS="FILETAG(AUTOCVT,AUTOTAG) POSIX(ON)"
export _TAG_REDIR_IN=txt
export _TAG_REDIR_OUT=txt
export _TAG_REDIR_ERR=txt
export _BPXK_AUTOCVT="ON"
export _EDC_ADD_ERRNO2=1                        # show details on error
unset ENV             # just in case, as it can cause unexpected output

# Leveraging the configmgr scripting is by opt-in of a config parameter or flag
# However, configmgr-only config file specifications also exist
# So if we see it in ZWE_CLI_PARAMETER_CONFIG we can also consider that opt-in
check_configmgr_enabled() {
  USE_CONFIGMGR=${ZWE_CLI_PARAMETER_CONFIGMGR}
  if [ -n "${USE_CONFIGMGR}" ]; then
    echo $USE_CONFIGMGR
  elif [ -n "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
    if [[ ${ZWE_CLI_PARAMETER_CONFIG} == "FILE("* ]]
    then
      echo "true"
    elif [[ ${ZWE_CLI_PARAMETER_CONFIG} == "PARMLIB("* ]]
    then
      echo "true"
    else
      USE_CONFIGMGR=$(shell_read_yaml_config "${ZWE_CLI_PARAMETER_CONFIG}" 'zowe' 'useConfigmgr')
      if [ "${USE_CONFIGMGR}" = "false" ]; then
        echo "false"
      else
        echo "true"
      fi
    fi
  fi
}

require_zowe_yaml() {
  # node is required to read yaml file
  require_node

  if [ -z "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
    print_error_and_exit "Error ZWEL0108E: Zowe YAML config file is required." "" 108
  elif [ ! -f "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
    print_error_and_exit "Error ZWEL0109E: The Zowe YAML config file specified does not exist." "" 109
  fi
}

print_raw_message() {
  message="${1}"
  is_error="${2}"
  # can be combination of log and/or console
  # default to write to both
  write_to=${3:-console,log}

  if [[ "${write_to}" = *console* ]]; then
    if [ "${is_error}" = "true" ]; then
      >&2 echo "${message}"
    elif [ "${ZWE_CLI_PARAMETER_SILENT}" != "true" ]; then
      echo "${message}"
    fi
  fi
  if [[ "${write_to}" = *log* ]]; then
    if [ -n "${ZWE_PRIVATE_LOG_FILE}" ]; then
      if [ -w "${ZWE_PRIVATE_LOG_FILE}" ]; then
        echo "${message}" >> $ZWE_PRIVATE_LOG_FILE
      else
        >&2 echo "WARNING: cannot write to ${ZWE_PRIVATE_LOG_FILE}"
      fi
    fi
  fi
}

print_message() {
  message="${1}"
  write_to="${2}"

  print_raw_message "${message}" "false" "${write_to}"
}

# errors are written to STDERR
print_error() {
  message="${1}"
  write_to="${2}"

  print_raw_message "${message}" "true" "${write_to}"
}

# debug message are written to STDERR
print_debug() {
  message="${1}"
  write_to="${2}"

  if [ "${ZWE_PRIVATE_LOG_LEVEL_ZWELS}" = "DEBUG" -o "${ZWE_PRIVATE_LOG_LEVEL_ZWELS}" = "TRACE" ]; then
    print_raw_message "${message}" "true" "${write_to}"
  fi
}

# trace messages are written to STDERR
print_trace() {
  message="${1}"
  write_to="${2}"

  if [ "${ZWE_PRIVATE_LOG_LEVEL_ZWELS}" = "TRACE" ]; then
    print_raw_message "${message}" "true" "${write_to}"
  fi
}

print_error_and_exit() {
  message="${1}"
  write_to="${2}"
  # default exit code is 1
  exit_code=${3:-1}

  print_error "${message}" "${write_to}"
  exit ${exit_code}
}

print_empty_line() {
  # can be combination of log and/or console
  write_to="${1}"

  print_message "" "${write_to}"
}

print_level0_message() {
  title="${1}"
  # can be combination of log and/or console
  write_to="${2}"

  print_message "===============================================================================" "${write_to}"
  if [ -n "${title}" ]; then
    print_message ">> $(echo "${title}" | upper_case )" "${write_to}"
  fi
  print_message "" "${write_to}"
}

print_level1_message() {
  title="${1}"
  # can be combination of log and/or console
  write_to="${2}"

  print_message "-------------------------------------------------------------------------------" "${write_to}"
  if [ -n "${title}" ]; then
    print_message ">> ${title}" "${write_to}"
  fi
  print_message "" "${write_to}"
}

print_level2_message() {
  title="${1}"
  # can be combination of log and/or console
  write_to="${2}"

  print_message "" "${write_to}"
  if [ -n "${title}" ]; then
    print_message ">> ${title}" "${write_to}"
  fi
  print_message "" "${write_to}"
}

print_level0_debug() {
  title="${1}"
  # can be combination of log and/or console
  write_to="${2}"

  print_debug "===============================================================================" "${write_to}"
  if [ -n "${title}" ]; then
    print_debug ">> $(echo "${title}" | upper_case )" "${write_to}"
  fi
  print_debug "" "${write_to}"
}

print_level1_debug() {
  title="${1}"
  # can be combination of log and/or console
  write_to="${2}"

  print_debug "-------------------------------------------------------------------------------" "${write_to}"
  if [ -n "${title}" ]; then
    print_debug ">> ${title}" "${write_to}"
  fi
  print_debug "" "${write_to}"
}

print_level2_debug() {
  title="${1}"
  # can be combination of log and/or console
  write_to="${2}"

  print_debug "" "${write_to}"
  if [ -n "${title}" ]; then
    print_debug ">> ${title}" "${write_to}"
  fi
  print_debug "" "${write_to}"
}

print_level0_trace() {
  title="${1}"
  # can be combination of log and/or console
  write_to="${2}"

  print_trace "===============================================================================" "${write_to}"
  if [ -n "${title}" ]; then
    print_trace ">> $(echo "${title}" | upper_case )" "${write_to}"
  fi
  print_trace "" "${write_to}"
}

print_level1_trace() {
  title="${1}"
  # can be combination of log and/or console
  write_to="${2}"

  print_trace "-------------------------------------------------------------------------------" "${write_to}"
  if [ -n "${title}" ]; then
    print_trace ">> ${title}" "${write_to}"
  fi
  print_trace "" "${write_to}"
}

print_level2_trace() {
  title="${1}"
  # can be combination of log and/or console
  write_to="${2}"

  print_trace "" "${write_to}"
  if [ -n "${title}" ]; then
    print_trace ">> ${title}" "${write_to}"
  fi
  print_trace "" "${write_to}"
}

# runtime logging functions, follow zowe service logging standard
print_formatted_message() {
  service="${1}"
  logger="${2}"
  level="${3}"
  message="${4}"

  if [ "${message}" = "-" ]; then
    read message
    if [ -z "${message}" ]; then
      # empty input
      return 0
    fi
  fi

  # always use upper case
  level=$(echo "${level}" | upper_case)

  # decide if we need to write log based on log level setting ZWE_PRIVATE_LOG_LEVEL_<service>
  expected_log_level_val=$(get_var_value "ZWE_PRIVATE_LOG_LEVEL_${service}" | upper_case)
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
