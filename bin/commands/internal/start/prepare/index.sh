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

################################################################################
# This command prepares everything needed to start Zowe.
################################################################################

################################################################################
# FUNCTIONS

########################################################
# Extra preparations for running in container
# - link component runtime under zowe <runtime>/components
# - `commands.configureInstance` is deprecated in v2
prepare_running_in_container() {
  # gracefully shutdown all processes
  print_formatted_debug "ZWELS" "zwe-internal-start-prepare,prepare_running_in_container:${LINENO}" "Register SIGTERM handler for graceful shutdown."
  trap gracefully_shutdown SIGTERM

  # read ZWE_PRIVATE_CONTAINER_COMPONENT_ID from component manifest
  # /component is hardcoded path we asked for in conformance
  if [ -z "${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}" ]; then
    export ZWE_PRIVATE_CONTAINER_COMPONENT_ID=$(read_component_manifest /component '.name')
  fi

  print_formatted_trace "ZWELS" "zwe-internal-start-prepare,prepare_running_in_container:${LINENO}" "Prepare <runtime>/components/${ZWE_PRIVATE_CONTAINER_COMPONENT_ID} directory."
  if [ -e "${ZWE_zowe_runtimeDirectory}/components/${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}" ]; then
    rm -fr "${ZWE_zowe_runtimeDirectory}/components/${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}"
  fi
  # we have hardcoded path for component runtime directory
  ln -sfn /component "${ZWE_zowe_runtimeDirectory}/components/${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}"
}

########################################################
# Prepare workspace directory
prepare_workspace_directory() {
  export ZWE_PRIVATE_WORKSPACE_ENV_DIR="${ZWE_zowe_workspaceDirectory}/.env"
  export ZWE_STATIC_DEFINITIONS_DIR="${ZWE_zowe_workspaceDirectory}/api-mediation/api-defs"
  export ZWE_GATEWAY_SHARED_LIBS=${ZWE_zowe_workspaceDirectory}/gateway/sharedLibs/

  mkdir -p "${ZWE_zowe_workspaceDirectory}"

  if [ ! -w "${ZWE_zowe_workspaceDirectory}" ]; then
    print_formatted_error "ZWELS" "zwe-internal-start-prepare,prepare_workspace_directory:${LINENO}" "ZWEL0141E: User $(get_user_id) does not have write permission on ${ZWE_zowe_workspaceDirectory}."
    exit 141
  fi

  # create apiml static defs directory
  mkdir -p "${ZWE_STATIC_DEFINITIONS_DIR}"
  # create apiml gateway share library directory
  mkdir -p "${ZWE_GATEWAY_SHARED_LIBS}"

  # Copy Zowe manifest into WORKSPACE_DIR so we know the version for support enquiries/migration
  cp ${ZWE_zowe_runtimeDirectory}/manifest.json ${ZWE_zowe_workspaceDirectory}

  # prepare .env directory
  mkdir -p "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}"
  # should we do chmod -R?
  # we lock this folder for zowe runtime user
  chmod -R 700 "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}"

  print_formatted_debug "ZWELS" "zwe-internal-start-prepare,prepare_workspace_directory:${LINENO}" "initialize .instance-${ZWE_CLI_PARAMETER_HA_INSTANCE}.env(s)"
  generate_instance_env_from_yaml_config "${ZWE_CLI_PARAMETER_HA_INSTANCE}"
}

########################################################
# Global validations
global_validate() {
  print_formatted_info "ZWELS" "zwe-internal-start-prepare,global_validate:${LINENO}" "process global validations ..."

  # validate_runtime_user
  if [ "${USER}" = "IZUSVR" ]; then
    print_formatted_warn "ZWELS" "zwe-internal-start-prepare,global_validate:${LINENO}" "ZWEL0142W: You are running the Zowe process under user id IZUSVR. This is not recommended and may impact your z/OS MF server negatively."
  fi

  # reset error counter
  export ZWE_PRIVATE_ERRORS_FOUND=0

  if [ ! -f "${ZWE_zowe_workspaceDirectory}/.init-for-container" ]; then
    # only do these check when it's not running in container

    # currently node is always required
    validate_this "validate_node_home 2>&1" "zwe-internal-start-prepare,global_validate:${LINENO}"

    # validate java for some core components
    if [[ ${ZWE_ENABLED_COMPONENTS} == *"gateway"* || ${ZWE_ENABLED_COMPONENTS} == *"discovery"* || ${ZWE_ENABLED_COMPONENTS} == *"api-catalog"* || ${ZWE_ENABLED_COMPONENTS} == *"caching-service"* || ${ZWE_ENABLED_COMPONENTS} == *"metrics-service"* || ${ZWE_ENABLED_COMPONENTS} == *"files-api"* || ${ZWE_ENABLED_COMPONENTS} == *"jobs-api"* ]]; then
      validate_this "validate_java_home 2>&1" "zwe-internal-start-prepare,global_validate:${LINENO}"
    fi
  else
    if [ -z "${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}" -o "${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}" = "null" ]; then
      validate_this "is_variable_set \"ZWE_PRIVATE_CONTAINER_COMPONENT_ID\" \"Cannot find name from the component image manifest file\" 2>&1" "zwe-internal-start-prepare,global_validate:${LINENO}"
    fi
  fi

  # validate z/OSMF for some core components
  if [ -n "${ZOSMF_HOST}" -a -n "${ZOSMF_PORT}" ]; then
    if [[ ${ZWE_ENABLED_COMPONENTS} == *"discovery"* || ${ZWE_ENABLED_COMPONENTS} == *"files-api"* || ${ZWE_ENABLED_COMPONENTS} == *"jobs-api"* ]]; then
      validate_this "validate_zosmf_host_and_port \"${ZOSMF_HOST}\" \"${ZOSMF_PORT}\" 2>&1" "zwe-internal-start-prepare,global_validate:${LINENO}"
    fi
  elif [ "${ZWE_components_gateway_apiml_security_auth_provider}" = "zosmf" ]; then
    validate_this "validate_zosmf_as_auth_provider \"${ZOSMF_HOST}\" \"${ZOSMF_PORT}\" \"${ZWE_components_gateway_apiml_security_auth_provider}\" 2>&1" "zwe-internal-start-prepare,global_validate:${LINENO}"
  fi

  check_runtime_validation_result "zwe-internal-start-prepare,global_validate:${LINENO}"

  print_formatted_info "ZWELS" "zwe-internal-start-prepare,global_validate:${LINENO}" "global validations are successful"
}

########################################################
# Validate component properties if script exists
validate_components() {
  print_formatted_info "ZWELS" "zwe-internal-start-prepare,validate_components:${LINENO}" "process component validations ..."

  # reset error counter
  export ZWE_PRIVATE_ERRORS_FOUND=0

  for component_id in $(echo "${ZWE_ENABLED_COMPONENTS}" | sed "s/,/ /g"); do
    print_formatted_trace "ZWELS" "zwe-internal-start-prepare,validate_components:${LINENO}" "- checking ${component_id}"
    component_dir=$(find_component_directory "${component_id}")
    print_formatted_trace "ZWELS" "zwe-internal-start-prepare,validate_components:${LINENO}" "- in directory ${component_dir}"
    if [ -n "${component_dir}" ]; then
      cd "${component_dir}"

      # check validate script
      validate_script=$(read_component_manifest "${component_dir}" ".commands.validate" 2>/dev/null)
      print_formatted_trace "ZWELS" "zwe-internal-start-prepare,validate_components:${LINENO}" "- commands.validate is ${validate_script:-<undefined>}"
      if [ -n "${validate_script}" -a "${validate_script}" != "null" -a -x "${validate_script}" ]; then
        print_formatted_debug "ZWELS" "zwe-internal-start-prepare,validate_components:${LINENO}" "- process ${component_id} validate command ..."
        ZWE_PRIVATE_OLD_ERRORS_FOUND=${ZWE_PRIVATE_ERRORS_FOUND}
        ZWE_PRIVATE_ERRORS_FOUND=0
        (load_environment_variables "${component_id}" && . "${validate_script}" 2>&1 && return ${ZWE_PRIVATE_ERRORS_FOUND})
        retval=$?
        let "ZWE_PRIVATE_ERRORS_FOUND=${ZWE_PRIVATE_OLD_ERRORS_FOUND}+${retval}"
      fi

      # check platform dependencies
      if [ "${ZWE_RUN_ON_ZOS}" != "true" ]; then
        zos_deps=$(read_component_manifest "${component_dir}" ".dependencies.zos" 2>/dev/null)
        if [ -n "${zos_deps}" -a "${zos_deps}" != "null" ]; then
          print_formatted_warn "ZWELS" "zwe-internal-start-prepare,validate_components:${LINENO}" "- ${component_id} depends on z/OS service(s). This dependency may require additional setup, please refer to the component documentation"
        fi
      fi
    fi
  done
  
  check_runtime_validation_result "zwe-internal-start-prepare,validate_components:${LINENO}"

  print_formatted_debug "ZWELS" "zwe-internal-start-prepare,validate_components:${LINENO}" "component validations are successful"
}

########################################################
# Run setup/configure on components if script exists
configure_components() {
  print_formatted_info "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "process component configurations ..."
  for component_id in $(echo "${ZWE_ENABLED_COMPONENTS}" | sed "s/,/ /g"); do
    print_formatted_trace "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "- checking ${component_id}"
    component_dir=$(find_component_directory "${component_id}")
    print_formatted_trace "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "- in directory ${component_dir}"
    if [ -n "${component_dir}" ]; then
      cd "${component_dir}"

      # prepare component workspace
      component_name=$(basename "${component_dir}")
      mkdir -p "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}"

      print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "- configure ${component_id}"

      # check configure script
      preconfigure_script=$(read_component_manifest "${component_dir}" ".commands.preConfigure" 2>/dev/null)
      print_formatted_trace "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "- commands.preConfigure is ${preconfigure_script:-<undefined>}"
      if [ "${preconfigure_script}" = "null" ]; then
        preconfigure_script=
      fi
      if [ -x "${preconfigure_script}" ]; then
        print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "* process ${component_id} pre-configure command ..."
        # execute configure step and snapshot environment
        result=$(load_environment_variables "${component_id}" && . "${preconfigure_script}")
        retval=$?
        if [ -n "${result}" ]; then
          if [ "${retval}" = "0" ]; then
            print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
          else
            print_formatted_error "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
          fi
        fi
      fi

      # default build-in behaviors
      # - apiml static definitions
      result=$(process_component_apiml_static_definitions "${component_dir}" 2>&1)
      retval=$?
      if [ -n "${result}" ]; then
        if [ "${retval}" = "0" ]; then
          print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
        else
          print_formatted_error "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
        fi
      fi
      # - generic app framework plugin
      result=$(process_component_appfw_plugin "${component_dir}" 2>&1)
      retval=$?
      if [ -n "${result}" ]; then
        if [ "${retval}" = "0" ]; then
          print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
        else
          print_formatted_error "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
        fi
      fi

      # - gateway shared lib
      result=$(process_component_gateway_shared_libs "${component_dir}" 2>&1)
      retval=$?
      if [ -n "${result}" ]; then
        if [ "${retval}" = "0" ]; then
          print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
        else
          print_formatted_error "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
        fi
      fi

      # check configure script
      configure_script=$(read_component_manifest "${component_dir}" ".commands.configure" 2>/dev/null)
      print_formatted_trace "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "- commands.configure is ${configure_script:-<undefined>}"
      if [ "${configure_script}" = "null" ]; then
        configure_script=
      fi
      if [ -x "${configure_script}" ]; then
        print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "* process ${component_id} configure command ..."
        # execute configure step and snapshot environment
        result=$(load_environment_variables "${component_id}" && . ${configure_script} ; rc=$? ; get_environment_exports > "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}/.${ZWE_CLI_PARAMETER_HA_INSTANCE}.env" ; return $rc)
        retval=$?
        if [ -n "${result}" ]; then
          if [ "${retval}" = "0" ]; then
            print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
          else
            print_formatted_error "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
          fi
        fi
      fi
    fi
  done

  print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "component configurations are successful"
}

###############################
# Few early steps even before initialization

# we want to reset TMPDIR as early as possible
ZWE_zowe_workspaceDirectory=$(shell_read_yaml_config ${ZWE_CLI_PARAMETER_CONFIG} 'zowe' 'workspaceDirectory')
if [ -z "${ZWE_zowe_workspaceDirectory}" -o "${ZWE_zowe_workspaceDirectory}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe workspace directory (zowe.workspaceDirectory) is not defined in Zowe YAML configuration file." "" 157
fi
# write tmp to here so we can enable readOnlyRootFilesystem
if [ -f "${ZWE_zowe_workspaceDirectory}/.init-for-container" ]; then
  print_formatted_trace "ZWELS" "zwe-internal-start-prepare:${LINENO}" "Setting TMPDIR to ${ZWE_zowe_workspaceDirectory}/.tmp."
  mkdir -p "${ZWE_zowe_workspaceDirectory}/.tmp"
  export TMPDIR=${ZWE_zowe_workspaceDirectory}/.tmp
  export TMP=${ZWE_zowe_workspaceDirectory}/.tmp
fi

# Fix node.js piles up in IPC message queue
# run this before any node command we start
if [ "${ZWE_RUN_ON_ZOS}" = "true" ]; then
  print_formatted_trace "ZWELS" "zwe-internal-start-prepare:${LINENO}" "Clean up IPC message queue before using node.js."
  ${ZWE_zowe_runtimeDirectory}/bin/utils/cleanup-ipc-mq.sh
fi

###############################
# display starting information
print_formatted_info "ZWELS" "zwe-internal-start-prepare:${LINENO}" "Zowe version: v$(shell_read_json_config ${ZWE_zowe_runtimeDirectory}/manifest.json 'version' 'version')"
print_formatted_info "ZWELS" "zwe-internal-start-prepare:${LINENO}" "build and hash: $(shell_read_json_config ${ZWE_zowe_runtimeDirectory}/manifest.json 'build' 'branch')#$(shell_read_json_config ${ZWE_zowe_runtimeDirectory}/manifest.json 'build' 'number') ($(shell_read_json_config ${ZWE_zowe_runtimeDirectory}/manifest.json 'build' 'commitHash'))"
print_formatted_info "ZWELS" "zwe-internal-start-prepare:${LINENO}" "starting Zowe instance ${ZWE_CLI_PARAMETER_HA_INSTANCE} with ${ZWE_CLI_PARAMETER_CONFIG} ..."

###############################
# validation
require_zowe_yaml

export ZWE_PRIVATE_LOG_LEVEL_ZWELS=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.launchScript.logLevel" | upper_case)
# overwrite ZWE_PRIVATE_LOG_LEVEL_CLI with ZWE_PRIVATE_LOG_LEVEL_ZWELS
ZWE_PRIVATE_LOG_LEVEL_CLI="${ZWE_PRIVATE_LOG_LEVEL_ZWELS}"

# check and sanitize ZWE_CLI_PARAMETER_HA_INSTANCE
if [ -z "${ZWE_CLI_PARAMETER_HA_INSTANCE}" ]; then
  ZWE_CLI_PARAMETER_HA_INSTANCE=$(get_sysname)
fi
# sanitize instance id
ZWE_CLI_PARAMETER_HA_INSTANCE=$(echo "${ZWE_CLI_PARAMETER_HA_INSTANCE}" | lower_case | sanitize_alphanum)

# extra preparations for running in container 
# this is running in containers
if [ -f "${ZWE_zowe_workspaceDirectory}/.init-for-container" ]; then
  prepare_running_in_container
fi

# init workspace directory and load environment variables
prepare_workspace_directory

# now we can load all variables
load_environment_variables
print_formatted_trace "ZWELS" "zwe-internal-start-prepare:${LINENO}" ">>> all environmen variables"
print_formatted_trace "ZWELS" "zwe-internal-start-prepare:${LINENO}" "$(env)"
print_formatted_trace "ZWELS" "zwe-internal-start-prepare:${LINENO}" "<<<"

###############################
# main lifecycle
# global validations
# no validation for running in container
global_validate
# no validation for running in container
if [ ! -f "${ZWE_zowe_workspaceDirectory}/.init-for-container" ]; then
  validate_components
fi
configure_components

###############################
# display instance prepared info
print_formatted_info "ZWELS" "zwe-internal-start-prepare:${LINENO}" "Zowe runtime environment prepared"
