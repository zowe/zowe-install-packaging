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

USE_CONFIGMGR=${ZWE_CLI_PARAMETER_CONFIGMGR}
if [ -n "${ZWE_CLI_PARAMETER_CONFIG}" -a "${USE_CONFIGMGR}" != "true" ]; then
  USE_CONFIGMGR=$(shell_read_yaml_config "${ZWE_CLI_PARAMETER_CONFIG}" 'zowe' 'useConfigmgr')
fi
if [ "${USE_CONFIGMGR}" = "true" ]; then
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/internal/start/component/cli.js"
else


###############################
# validation
if [ "$(item_in_list "${ZWE_PRIVATE_CORE_COMPONENTS_REQUIRE_JAVA}" "${ZWE_CLI_PARAMETER_COMPONENT}")" = "true" ]; then
  # other extensions need to specify `require_java` in their validate.sh
  require_java
fi
require_node
require_zowe_yaml

# overwrite ZWE_PRIVATE_LOG_LEVEL_ZWELS with zowe.launchScript.logLevel config in YAML
ZWE_PRIVATE_LOG_LEVEL_ZWELS="$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.launchScript.logLevel" | upper_case)"

# check and sanitize ZWE_CLI_PARAMETER_HA_INSTANCE
sanitize_ha_instance_id

ZWE_zowe_workspaceDirectory=$(read_yaml ${ZWE_CLI_PARAMETER_CONFIG} '.zowe.workspaceDirectory')
if [ -z "${ZWE_zowe_workspaceDirectory}" ]; then
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
  if [ -f "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}/.${ZWE_CLI_PARAMETER_HA_INSTANCE}.env" ]; then
    print_formatted_debug "ZWELS" "zwe-internal-start-component:${LINENO}" "restoring environment snapshot ${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}/.${ZWE_CLI_PARAMETER_HA_INSTANCE}.env ..."
    # some variables we don't want to be overwritten
    ZWE_OLD_CLI_PARAMETER_COMPONENT=${ZWE_CLI_PARAMETER_COMPONENT}
    # restore environment snapshot created in configure step
    . "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}/.${ZWE_CLI_PARAMETER_HA_INSTANCE}.env"
    # restore some backups
    ZWE_CLI_PARAMETER_COMPONENT=${ZWE_OLD_CLI_PARAMETER_COMPONENT}
  fi

  start_script=$(read_component_manifest "${component_dir}" ".commands.start" 2>/dev/null)
  print_formatted_trace "ZWELS" "zwe-internal-start-component:${LINENO}" "- command.start of ${ZWE_CLI_PARAMETER_COMPONENT} is ${start_script}"

  if [ -n "${start_script}" ]; then
    if [ -f "${start_script}" ]; then
      print_formatted_info "ZWELS" "zwe-internal-start-component:${LINENO}" "starting component ${ZWE_CLI_PARAMETER_COMPONENT} ..."
      print_formatted_trace "ZWELS" "zwe-internal-start-component:${LINENO}" "$(printf ">>> environment for %s\n%s\n<<<" "${ZWE_CLI_PARAMETER_COMPONENT}" "$(get_environments)")"
      # FIXME: we have assumption here start_script is pointing to a shell script
      # if [[ "${start_script}" == *.sh ]]; then
      if [ "${ZWE_CLI_PARAMETER_RUN_IN_BACKGROUND}" = "true" ]; then
        . "${start_script}" &
      else
        # wait for all background subprocesses created by bin/start.sh exit
        # re-source libs is necessary to reclaim shell functions since this will be executed in a new shell
        cat "${start_script}" | { echo ". \"${ZWE_zowe_runtimeDirectory}/bin/libs/index.sh\"" ; cat ; echo; echo wait; } | /bin/sh
      fi
    else
      print_formatted_error "ZWELS" "zwe-internal-start-component:${LINENO}" "Error ZWEL0172E: Component ${ZWE_CLI_PARAMETER_COMPONENT} has commands.start defined but the file is missing."
    fi
  else
    print_formatted_trace "ZWELS" "zwe-internal-start-component:${LINENO}" "Component ${ZWE_CLI_PARAMETER_COMPONENT} doesn't have start command."
  fi
else
  print_formatted_error "ZWELS" "zwe-internal-start-component:${LINENO}" "Failed to locate component directory for ${ZWE_CLI_PARAMETER_COMPONENT}."
fi

fi
