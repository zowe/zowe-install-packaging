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

USE_CONFIGMGR=$(check_configmgr_enabled)
if [ "${USE_CONFIGMGR}" = "true" ]; then
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/internal/start/prepare/cli.js"
else


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
# Prepare log directory
prepare_log_directory() {
  # TODO: is it ok ZWE_zowe_logDirectory is not defined?
  if [ -n "${ZWE_zowe_logDirectory}" ]; then
    mkdir -p "${ZWE_zowe_logDirectory}"

    if [ ! -w "${ZWE_zowe_logDirectory}" ]; then
      print_formatted_error "ZWELS" "zwe-internal-start-prepare,prepare_log_directory:${LINENO}" "ZWEL0141E: User $(get_user_id) does not have write permission on ${ZWE_zowe_logDirectory}."
      exit 141
    fi
  fi
}

########################################################
# Prepare workspace directory
prepare_workspace_directory() {
  export ZWE_PRIVATE_WORKSPACE_ENV_DIR="${ZWE_zowe_workspaceDirectory}/.env"
  export ZWE_STATIC_DEFINITIONS_DIR="${ZWE_zowe_workspaceDirectory}/api-mediation/api-defs"
  export ZWE_GATEWAY_SHARED_LIBS="${ZWE_zowe_workspaceDirectory}/gateway/sharedLibs/"
  export ZWE_DISCOVERY_SHARED_LIBS="${ZWE_zowe_workspaceDirectory}/discovery/sharedLibs/"

  mkdir -p "${ZWE_zowe_workspaceDirectory}"

  if [ ! -w "${ZWE_zowe_workspaceDirectory}" ]; then
    print_formatted_error "ZWELS" "zwe-internal-start-prepare,prepare_workspace_directory:${LINENO}" "ZWEL0141E: User $(get_user_id) does not have write permission on ${ZWE_zowe_workspaceDirectory}."
    exit 141
  fi

  # set workspace dir permission
  # FIXME: 771 is inherited from v1, we should consider disable read permission for `other`
  umask 0002
  result=$(chmod -R 771 "${ZWE_zowe_workspaceDirectory}" 2>&1)
  code=$?
  if [ ${code} -ne 0 ]; then
    print_formatted_error "ZWELS" "zwe-internal-start-prepare,prepare_workspace_directory:${LINENO}" "WARNING: Failed to set permission of some existing files or directories in ${ZWE_zowe_workspaceDirectory}:"
    print_formatted_error "ZWELS" "zwe-internal-start-prepare,prepare_workspace_directory:${LINENO}" "${result}"
  fi

  # create apiml static defs directory
  mkdir -p "${ZWE_STATIC_DEFINITIONS_DIR}"
  # create apiml gateway share library directory
  mkdir -p "${ZWE_GATEWAY_SHARED_LIBS}"
  # create apiml discovery share library directory
  mkdir -p "${ZWE_DISCOVERY_SHARED_LIBS}"

  # Copy Zowe manifest into WORKSPACE_DIR so we know the version for support enquiries/migration
  cp ${ZWE_zowe_runtimeDirectory}/manifest.json ${ZWE_zowe_workspaceDirectory}

  # prepare .env directory
  mkdir -p "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}"

  print_formatted_debug "ZWELS" "zwe-internal-start-prepare,prepare_workspace_directory:${LINENO}" "initialize .instance-${ZWE_CLI_PARAMETER_HA_INSTANCE}.env(s)"
  generate_instance_env_from_yaml_config "${ZWE_CLI_PARAMETER_HA_INSTANCE}"

  # we lock this folder only for zowe runtime user
  chmod -R 700 "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}"
}

########################################################
# Global validations
global_validate() {
  print_formatted_info "ZWELS" "zwe-internal-start-prepare,global_validate:${LINENO}" "process global validations ..."

  # validate_runtime_user
  if [ "${USER}" = "IZUSVR" ]; then
    print_formatted_warn "ZWELS" "zwe-internal-start-prepare,global_validate:${LINENO}" "ZWEL0302W: You are running the Zowe process under user id IZUSVR. This is not recommended and may impact your z/OS MF server negatively."
  fi

  # reset error counter
  export ZWE_PRIVATE_ERRORS_FOUND=0

  validate_this "is_directory_writable \"${ZWE_zowe_workspaceDirectory}\" 2>&1" "zwe-internal-start-prepare,global_validate:${LINENO}"

  if [ "${ZWE_RUN_IN_CONTAINER}" != "true" ]; then
    # only do these check when it's not running in container

    # currently node is always required
    validate_this "validate_node_home 2>&1" "zwe-internal-start-prepare,global_validate:${LINENO}"

    # validate java for some core components
    if [[ ${ZWE_ENABLED_COMPONENTS} == *"gateway"* || ${ZWE_ENABLED_COMPONENTS} == *"cloud-gateway"* || ${ZWE_ENABLED_COMPONENTS} == *"discovery"* || ${ZWE_ENABLED_COMPONENTS} == *"api-catalog"* || ${ZWE_ENABLED_COMPONENTS} == *"caching-service"* || ${ZWE_ENABLED_COMPONENTS} == *"metrics-service"* || ${ZWE_ENABLED_COMPONENTS} == *"files-api"* || ${ZWE_ENABLED_COMPONENTS} == *"jobs-api"* ]]; then
      validate_this "validate_java_home 2>&1" "zwe-internal-start-prepare,global_validate:${LINENO}"
    fi
  else
    if [ -z "${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}" ]; then
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
      if [ -n "${validate_script}" ]; then
        if [ -f "${validate_script}" ]; then
          print_formatted_debug "ZWELS" "zwe-internal-start-prepare,validate_components:${LINENO}" "- process ${component_id} validate command ..."
          ZWE_PRIVATE_OLD_ERRORS_FOUND=${ZWE_PRIVATE_ERRORS_FOUND}
          ZWE_PRIVATE_ERRORS_FOUND=0
          (load_environment_variables "${component_id}" && . "${validate_script}" 2>&1 && return ${ZWE_PRIVATE_ERRORS_FOUND})
          retval=$?
          let "ZWE_PRIVATE_ERRORS_FOUND=${ZWE_PRIVATE_OLD_ERRORS_FOUND}+${retval}"
        else
          print_formatted_error "ZWELS" "zwe-internal-start-prepare,validate_components:${LINENO}" "Error ZWEL0172E: Component ${component_id} has commands.validate defined but the file is missing."
        fi
      fi

      # check platform dependencies
      if [ "${ZWE_RUN_ON_ZOS}" != "true" ]; then
        zos_deps=$(read_component_manifest "${component_dir}" ".dependencies.zos" 2>/dev/null)
        if [ -n "${zos_deps}" ]; then
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
      component_name=$(read_component_manifest "${component_dir}" ".name")
      mkdir -p "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}"
      if [ -e "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}" ]; then
        chmod 700 "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}"
      fi

      # copy manifest to workspace
      component_manifest=$(get_component_manifest "${component_dir}")
      if [ ! -z "${component_manifest}" -a -f "${component_manifest}" ]; then
        cp "${component_manifest}" "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}/"
      fi

      print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "- configure ${component_id}"

      # check configure script
      preconfigure_script=$(read_component_manifest "${component_dir}" ".commands.preConfigure" 2>/dev/null)
      print_formatted_trace "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "- commands.preConfigure is ${preconfigure_script:-<undefined>}"
      if [ -n "${preconfigure_script}" ]; then
        if [ -f "${preconfigure_script}" ]; then
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
        else
          print_formatted_error "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "Error ZWEL0172E: Component ${component_id} has commands.preConfigure defined but the file is missing."
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

      # - discovery shared lib
      result=$(process_component_discovery_shared_libs "${component_dir}" 2>&1)
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
      if [ -n "${configure_script}" ]; then
        if [ -f "${configure_script}" ]; then
          print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "* process ${component_id} configure command ..."
          # execute configure step and generate environment snapshot
          result=$(load_environment_variables "${component_id}" && . ${configure_script} ; rc=$? ; get_environment_exports > "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}/.${ZWE_CLI_PARAMETER_HA_INSTANCE}.env" ; return $rc)
          retval=$?
          # set permission for the component environment snapshot
          if [ -f "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}/.${ZWE_CLI_PARAMETER_HA_INSTANCE}.env" ]; then
            chmod 700 "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/${component_name}/.${ZWE_CLI_PARAMETER_HA_INSTANCE}.env"
          fi
          if [ -n "${result}" ]; then
            if [ "${retval}" = "0" ]; then
              print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
            else
              print_formatted_error "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "${result}"
            fi
          fi
        else
          print_formatted_error "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "Error ZWEL0172E: Component ${component_id} has commands.configure defined but the file is missing."
        fi
      fi
    fi
  done

  print_formatted_debug "ZWELS" "zwe-internal-start-prepare,configure_components:${LINENO}" "component configurations are successful"
}

###############################
# Few early steps even before initialization

# init ZWE_RUN_IN_CONTAINER variable
ZWE_zowe_workspaceDirectory=$(shell_read_yaml_config "${ZWE_CLI_PARAMETER_CONFIG}" 'zowe' 'workspaceDirectory')
if [ -z "${ZWE_zowe_workspaceDirectory}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe workspace directory (zowe.workspaceDirectory) is not defined in Zowe YAML configuration file." "" 157
fi
if [ -f "${ZWE_zowe_workspaceDirectory}/.init-for-container" ]; then
  export ZWE_RUN_IN_CONTAINER=true
fi

# Fix node.js piles up in IPC message queue
# run this before any node command we start
if [ "${ZWE_RUN_ON_ZOS}" = "true" -a "${ZWE_PRIVATE_CLEANUP_IPC_MQ}" = "true" ]; then
  print_formatted_trace "ZWELS" "zwe-internal-start-prepare:${LINENO}" "Clean up IPC message queue before using node.js."
  ${ZWE_zowe_runtimeDirectory}/bin/utils/cleanup-ipc-mq.sh
fi

###############################
# display starting information
export ZWE_VERSION=$(shell_read_json_config "${ZWE_zowe_runtimeDirectory}/manifest.json" 'version' 'version')
print_formatted_info "ZWELS" "zwe-internal-start-prepare:${LINENO}" "Zowe version: v${ZWE_VERSION}"
print_formatted_info "ZWELS" "zwe-internal-start-prepare:${LINENO}" "build and hash: $(shell_read_json_config ${ZWE_zowe_runtimeDirectory}/manifest.json 'build' 'branch')#$(shell_read_json_config ${ZWE_zowe_runtimeDirectory}/manifest.json 'build' 'number') ($(shell_read_json_config ${ZWE_zowe_runtimeDirectory}/manifest.json 'build' 'commitHash'))"

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
print_formatted_info "ZWELS" "zwe-internal-start-prepare:${LINENO}" "starting Zowe instance ${ZWE_CLI_PARAMETER_HA_INSTANCE} with ${ZWE_CLI_PARAMETER_CONFIG} ..."

# extra preparations for running in container 
# this is running in containers
if [ "${ZWE_RUN_IN_CONTAINER}" = "true" ]; then
  prepare_running_in_container
fi

# init log directory
prepare_log_directory

# init workspace directory and generate environment variables from YAML
prepare_workspace_directory

# now we can load all variables
load_environment_variables
print_formatted_trace "ZWELS" "zwe-internal-start-prepare:${LINENO}" ">>> all environment variables"
print_formatted_trace "ZWELS" "zwe-internal-start-prepare:${LINENO}" "$(env)"
print_formatted_trace "ZWELS" "zwe-internal-start-prepare:${LINENO}" "<<<"

###############################
# main lifecycle
# global validations
# no validation for running in container
global_validate
# no validation for running in container
if [ "${ZWE_RUN_IN_CONTAINER}" != "true" ]; then
  validate_components
fi
configure_components

###############################
# display instance prepared info
print_formatted_info "ZWELS" "zwe-internal-start-prepare:${LINENO}" "Zowe runtime environment prepared"

fi
