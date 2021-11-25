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

#######################################################################
# Global variables
export ZWE_CLI_COMMANDS_LIST=
export ZWE_CLI_PARAMETERS_LIST=
export ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS=
export ZWE_CLI_INTERNAL_IS_TOP_LEVEL_COMMAND=true
export ZWE_LOG_LEVEL_CLI=INFO

zwecli_append_parameters_definition() {
  if [ $# -eq 0 ]; then
    commands="${ZWE_CLI_COMMANDS_LIST}"
  else
    commands="${1}"
  fi

  command_path=$(zwecli_calculate_command_path "${commands}")
  if [ -d "${command_path}" ]; then
    if [ -f "${command_path}/.parameters" ]; then
      ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS="${ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS}\n$(cat "${command_path}/.parameters")"
    fi
  elif [ -n "${commands}" ]; then
    print_error "Error ZWEI0104E: Invalid command \"${commands}\""
    print_error_and_exit "Try --help to get information about what command(s) are available." "" 104
  fi
}

zwecli_append_exclusive_parameters_definition() {
  if [ $# -eq 0 ]; then
    commands="${ZWE_CLI_COMMANDS_LIST}"
  else
    commands="${1}"
  fi

  command_path=$(zwecli_calculate_command_path "${commands}")
  if [ -d "${command_path}" ]; then
    if [ -f "${command_path}/.exclusive-parameters" ]; then
      ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS="${ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS}\n$(cat "${command_path}/.exclusive-parameters")"
    fi
  elif [ -n "${commands}" ]; then
    print_error "Error ZWEI0104E: Invalid command \"${commands}\""
    print_error_and_exit "Try --help to get information about what command(s) are available." "" 104
  fi
}

zwecli_load_parameters_definition() {
  ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS=
  zwecli_append_parameters_definition ""
  sub_command_list=
  for command in ${ZWE_CLI_COMMANDS_LIST}; do
    sub_command_list="$(echo "${sub_command_list} ${command}" | trim)"
    zwecli_append_parameters_definition "${sub_command_list}"
  done
  zwecli_append_exclusive_parameters_definition
}

zwecli_locate_parameter_definition() {
  param=$1

  match=
  while read -r line; do
    first_line=$(echo "${line}" | head -n 1 | trim)
    if [ -n "${first_line}" ]; then
      line_params_full=$(echo "${first_line}" | awk -F"|" '{print $1};' | tr "," " ")
      if [ -n "${line_params_full}" ]; then
        for one in ${line_params_full}; do
          if [ "${param}" = "--${one}" ]; then
            match=${line}
            break
          fi
        done
      fi
      if [ -z "${match}" ]; then
        line_params_alias=$(echo "${first_line}" | awk -F"|" '{print $2};')
        if [ "${param}" = "-${line_params_alias}" ]; then
          match=${line}
        fi
      fi
      if [ -n "${match}" ]; then
        break
      fi
    fi
  done <<EOF
$(echo "${ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS}")
EOF

  if [ -n "${match}" ]; then
    echo "${match}"
    return 0
  else
    return 1
  fi
}

zwecli_get_parameter_variable() {
  param_id=$1

  echo "ZWE_CLI_PARAMETER_${param_id}" | upper_case | sanitize_alphanum
}

zwecli_get_parameter_value() {
  param_id=$1

  get_var_value "$(zwecli_get_parameter_variable "${param_id}")"
}

zwecli_set_parameter_value() {
  param_id=$1
  value=$2

  eval "export $(zwecli_get_parameter_variable "${param_id}")=${value}"
}

zwecli_load_parameters_default_value() {
  while read -r line; do
    first_line=$(echo "${line}" | head -n 1 | trim)
    if [ -n "${first_line}" ]; then
      param_id=$(echo "${first_line}" | awk -F"|" '{print $1}' | awk -F, '{print $1}')
      param_default_value=$(echo "${first_line}" | awk -F"|" '{print $5}')
      if [ -n "${param_default_value}" ]; then
        param_value=$(zwecli_get_parameter_value "${param_id}")
        if [ -z "${param_value}" ]; then
          ZWE_CLI_PARAMETERS_LIST=$(trim "${ZWE_CLI_PARAMETERS_LIST} ${param_id}")
          zwecli_set_parameter_value "${param_id}" "${param_default_value}"
        fi
      fi
    fi
  done <<EOF
$(echo "${ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS}")
EOF
}

zwecli_process_loglevel() {
  if [ "${ZWE_CLI_PARAMETER_DEBUG}" = "true" -o "${ZWE_CLI_PARAMETER_VERBOSE}" = "true" ]; then
    ZWE_LOG_LEVEL_CLI=DEBUG
  fi
  if [ "${ZWE_CLI_PARAMETER_TRACE}" = "true" ]; then
    ZWE_LOG_LEVEL_CLI=TRACE
  fi
}

zwecli_process_logfile() {
  if [ -n "${ZWE_CLI_PARAMETER_LOG_DIR}" ]; then
    cd "${ZWE_PWD}"

    log_prefix=zwe
    if [ -n "${ZWE_CLI_COMMANDS_LIST}" ]; then
      log_prefix=zwe-$(echo "${ZWE_CLI_COMMANDS_LIST}" | trim | sed 's/ /-/g')
    fi
    prepare_log_file "${ZWE_CLI_PARAMETER_LOG_DIR}" "${log_prefix}"

    # write initial information
    print_message "Zowe Server CLI: zwe ${ZWE_CLI_COMMANDS_LIST}" "log"
    print_message "- timestamp: $(date +"%Y-%m-%d %H:%M:%S")" "log"
    print_message "- parameters:" "log"
    for param in ${ZWE_CLI_PARAMETERS_LIST}; do
      print_message "  * ${param}: $(zwecli_get_parameter_value "${param}")" "log"
    done
    print_message "" "log"
  fi
}

zwecli_display_parameters_help() {
  file=$1

  while read -r line; do
    first_line=$(echo "${line}" | trim | head -n 1)
    if [ -n "${line}" ]; then
      display_param=
      line_params_full=$(echo "${first_line}" | awk -F"|" '{print $1};' | tr "," " ")
      for one in ${line_params_full}; do
        if [ -z "${display_param}" ]; then
          display_param="--${one}"
        else
          display_param="${display_param}|--${one}"
        fi
      done

      line_params_alias=$(echo "${first_line}" | awk -F"|" '{print $2};')
      if [ -n "${line_params_alias}" ]; then
        if [ -z "${display_param}" ]; then
          display_param="-${line_params_alias}"
        else
          display_param="${display_param}|-${line_params_alias}"
        fi
      fi

      line_params_type=$(echo "${first_line}" | awk -F"|" '{print $3};' | lower_case)
      if [ "${line_params_type}" = "b" -o "${line_params_type}" = "bool" ]; then
        line_params_type=boolean
      elif [ "${line_params_type}" = "s" -o "${line_params_type}" = "str" ]; then
        line_params_type=string
      fi

      line_params_requirement=$(echo "${first_line}" | awk -F"|" '{print $4};' | lower_case)

      line_params_help=$(echo "${line}" | sed -e 's#^[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|##')
      echo "  ${display_param}: ${line_params_type}, ${line_params_requirement:-optional}"
      padding_left "${line_params_help}" "    "
    fi
  done <<EOF
$(cat ${file})
EOF
}

zwecli_calculate_command_path() {
  if [ $# -eq 0 ]; then
    commands="${ZWE_CLI_COMMANDS_LIST}"
  else
    commands="${1}"
  fi

  if [ -z "${commands}" ]; then
    echo "${ZWE_zowe_runtimeDirectory}/bin/commands"
  else
    echo "${ZWE_zowe_runtimeDirectory}/bin/commands/$(echo "${commands}" | sed -e 's# #/#g')"
  fi
}

zwecli_process_help() {
  if [ "${ZWE_CLI_PARAMETER_HELP}" = "true" ]; then
    >&2 echo "Zowe Server CLI: zwe ${ZWE_CLI_COMMANDS_LIST}"
    >&2 echo

    # display help message if exists
    command_path=$(zwecli_calculate_command_path)
    if [ -f "${command_path}/.help" ]; then
      >&2 cat "${command_path}/.help"
      >&2 echo
    fi

    # display global parameters
    if [ -f "${ZWE_zowe_runtimeDirectory}/bin/commands/.parameters" ]; then
      >&2 echo "------------------"
      >&2 echo "Global parameters:"
      >&2 zwecli_display_parameters_help "${ZWE_zowe_runtimeDirectory}/bin/commands/.parameters"
      >&2 echo
    fi

    # display command parameters
    command_tree=
    command_path="${ZWE_zowe_runtimeDirectory}/bin/commands"
    for command in ${ZWE_CLI_COMMANDS_LIST}; do
      command_tree=$(echo "${command_tree} ${command}" | trim)
      command_path="${command_path}/${command}"
      if [ -f "${command_path}/.experimental" ]; then
        >&2 echo "WARNING: command \"${command_tree}\" is for experimental purpose."
        >&2 echo
      fi
      if [ -f "${command_path}/.parameters" -o -f "${command_path}/.exclusive-parameters" ]; then
        >&2 echo "------------------"
        >&2 echo "Parameters for command \"${command_tree}\":"
        if [ -f "${command_path}/.parameters" ]; then
          >&2 zwecli_display_parameters_help "${command_path}/.parameters"
        fi
        if [ -f "${command_path}/.exclusive-parameters" ]; then
          >&2 zwecli_display_parameters_help "${command_path}/.exclusive-parameters"
        fi
        >&2 echo
      fi
    done

    # find sub-commands
    command_path=$(zwecli_calculate_command_path)
    subdirs=$(find_sub_directories "${command_path}")
    if [ -n "${subdirs}" ]; then
      >&2 echo "------------------"
      >&2 echo "Available sub-command(s):"
      while read -r line; do
        echo "  - $(basename "${line}")"
      done <<EOF
$(echo "${subdirs}")
EOF
      echo
    fi

    exit 100
  fi
}

zwecli_validate_parameters() {
  required_params=
  while read -r line; do
    first_line=$(echo "${line}" | head -n 1 | trim)
    if [ -n "${first_line}" ]; then
      param_id=$(echo "${first_line}" | awk -F"|" '{print $1}' | awk -F, '{print $1}')
      param_requirement=$(echo "${first_line}" | awk -F"|" '{print $4}' | lower_case)
      if [ "${param_requirement}" = "required" ]; then
        required_params=$(echo "${required_params} ${param_id}" | trim)
      fi
    fi
  done <<EOF
$(echo "${ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS}")
EOF

  for param in ${required_params}; do
    val=$(zwecli_get_parameter_value "${param}")
    if [ -z "${val}" ]; then
      print_error "Error ZWEI0106E: ${param} parameter is required"
      print_error_and_exit "Try --help to get information about how to use this command." "" 106
    fi
  done
}

zwecli_process_command() {
  cd "${ZWE_PWD}"
  command_path=$(zwecli_calculate_command_path)
  if [ -f "${command_path}/index.sh" ]; then
    . "${command_path}/index.sh"
  else
    if [ -n "${ZWE_CLI_COMMANDS_LIST}" ]; then
      print_error "Error ZWEI0107E: No handler defined for command \"${ZWE_CLI_COMMANDS_LIST}\"."
    fi
    print_error_and_exit "Try --help to get information about how to use this command." "console" 107
  fi
}

zwecli_inline_execute_command() {
  # save current command
  saved_cli_commands_list="${ZWE_CLI_COMMANDS_LIST}"
  saved_cli_parameters_list="${ZWE_CLI_PARAMETERS_LIST}"
  saved_cli_parameters_definitions="${ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS}"

  export ZWE_CLI_INTERNAL_IS_TOP_LEVEL_COMMAND=false

  # process new command
  . "${ZWE_zowe_runtimeDirectory}/bin/zwe"

  # restore original command
  ZWE_CLI_COMMANDS_LIST="${saved_cli_commands_list}"
  ZWE_CLI_PARAMETERS_LIST="${saved_cli_parameters_list}"
  ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS="${saved_cli_parameters_definitions}"
}
