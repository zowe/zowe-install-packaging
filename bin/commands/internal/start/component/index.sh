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
# validation
require_zowe_yaml

# check and sanitize ZWE_CLI_PARAMETER_HA_INSTANCE
if [ -z "${ZWE_CLI_PARAMETER_HA_INSTANCE}" ]; then
  ZWE_CLI_PARAMETER_HA_INSTANCE=$(get_sysname)
fi
# sanitize instance id
ZWE_CLI_PARAMETER_HA_INSTANCE=$(echo "${ZWE_CLI_PARAMETER_HA_INSTANCE}" | lower_case | sanitize_alphanum)

ZWE_zowe_workspaceDirectory=$(read_yaml ${ZWE_CLI_PARAMETER_CONFIG} '.zowe.workspaceDirectory')
if [ -z "${ZWE_zowe_workspaceDirectory}" -o "${ZWE_zowe_workspaceDirectory}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe workspace directory (zowe.workspaceDirectory) is not defined in Zowe YAML configuration file." "" 157
fi

########################################################
# load environment
load_environment_variables "${ZWE_CLI_PARAMETER_COMPONENT}"

########################################################
# find component root directory and execute start script
component_dir=$(find_component_directory "${ZWE_CLI_PARAMETER_COMPONENT}")
print_formatted_trace "ZWELS" "zwe-internal-start-component:${LINENO}" "- found ${ZWE_CLI_PARAMETER_COMPONENT} in directory ${component_dir}"
if [ -n "${component_dir}" ]; then
  cd "${component_dir}"

  # source environment snapshot created by configure step
  component_name=$(basename "${component_dir}")
  if [ -f "${ZWELS_INSTANCE_ENV_DIR}/${component_name}/.${ZWELS_HA_INSTANCE_ID}.env" ]; then
    print_formatted_debug "ZWELS" "start-component.sh:${LINENO}" "restoring environment snapshot ${ZWELS_INSTANCE_ENV_DIR}/${component_name}/.${ZWELS_HA_INSTANCE_ID}.env ..."
    # some variables we don't want to be overwritten
    ZWE_OLD_CLI_PARAMETER_COMPONENT=${ZWE_CLI_PARAMETER_COMPONENT}
    # restore environment snapshot created in configure step
    . "${ZWELS_INSTANCE_ENV_DIR}/${component_name}/.${ZWELS_HA_INSTANCE_ID}.env"
    # restore some backups
    ZWE_CLI_PARAMETER_COMPONENT=${ZWE_OLD_CLI_PARAMETER_COMPONENT}
  fi

  start_script=$(read_component_manifest "${component_dir}" ".commands.start" 2>/dev/null)
  print_formatted_trace "ZWELS" "zwe-internal-start-component:${LINENO}" "- command.start of ${ZWE_CLI_PARAMETER_COMPONENT} is ${start_script}"
  if [ "${start_script}" = "null" ]; then
    start_script=
  fi

  if [ -x "${start_script}" ]; then
    print_formatted_info "ZWELS" "start-component.sh:${LINENO}" "starting component ${ZWE_CLI_PARAMETER_COMPONENT} ..."
    print_formatted_trace "ZWELS" "start-component.sh:${LINENO}" ">>> environment for ${ZWE_CLI_PARAMETER_COMPONENT}\n$(get_environments)\n<<<"
    # FIXME: we have assumption here start_script is pointing to a shell script
    # if [[ "${start_script}" == *.sh ]]; then
    if [ "${ZWE_CLI_PARAMETER_RUN_IN_BACKGROUND}" = "true" ]; then
      . "${start_script}" &
    else
      # wait for all background subprocesses created by bin/start.sh exit
      cat "${start_script}" | { cat ; echo; echo wait; } | /bin/sh
    fi
  fi
fi
