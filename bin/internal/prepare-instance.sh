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

################################################################################
# This script prepares everything needed for starting Zowe.
#
# It takes 2 parameters, same as bin/internal/run-zowe.sh
# - c:   path to instance directory
# - i:   optional, Zowe HA instance ID
################################################################################

################################################################################
# FUNCTIONS

########################################################
# Prepare <instance>/.env directory
#
# usually creating instance.env from yaml config has 2 steps:
# 1. components .manifest.json are not ready yet, we can only generate <.env>/.instance-<ha-id>.env
# 2. components .manifest.json are ready, we should also generate <.env>/<component>/.instance-<ha-id>.env
prepare_instance_env_directory() {
  mkdir -p "${ZWELS_INSTANCE_ENV_DIR}"
  # should we do chmod -R?
  chmod 750 "${ZWELS_INSTANCE_ENV_DIR}"

  if [ "${ZWELS_CONFIG_LOAD_METHOD}" = "zowe.yaml" ]; then
    # this is step 1
    print_formatted_debug "ZWELS" "prepare-instance.sh,prepare_instance_env_directory:${LINENO}" "initialize .instance-${ZWELS_HA_INSTANCE_ID}.env(s)"
    generate_instance_env_from_yaml_config "${ZWELS_HA_INSTANCE_ID}"
  fi

  # now we can load all variables, we need LAUNCH_COMPONENTS for next step
  . ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -i "${ZWELS_HA_INSTANCE_ID}"
  # copy over component manifest
  convert_all_component_manifests_to_json
  if [ "${ZWELS_CONFIG_LOAD_METHOD}" = "zowe.yaml" ]; then
    # this is step 2
    # at this point, <instance>/.env/<component>/.manifest.json should be in place
    # re-generate components instance.env
    print_formatted_debug "ZWELS" "prepare-instance.sh,prepare_instance_env_directory:${LINENO}" "refresh component copy of .instance-${ZWELS_HA_INSTANCE_ID}.env(s)"
    generate_instance_env_from_yaml_config "${ZWELS_HA_INSTANCE_ID}"
  fi
}

########################################################
# Global validations
global_validate() {
  print_formatted_info "ZWELS" "prepare-instance.sh,global_validate:${LINENO}" "process global validations ..."

  if [[ "${USER}" == "IZUSVR" ]]
  then
    print_formatted_warn "ZWELS" "prepare-instance.sh,global_validate:${LINENO}" "You are running the Zowe process under user id IZUSVR. This is not recommended and may impact your z/OS MF server negatively."
  fi

  # reset error counter
  export ERRORS_FOUND=0

  # Make sure INSTANCE_DIR is accessible and writable to the user id running this
  validate_directory_is_writable "${INSTANCE_DIR}"

  # Validate keystore directory accessible
  validate_directory_is_accessible "${KEYSTORE_DIRECTORY}"

  # ZOWE_PREFIX shouldn't be too long
  validate_zowe_prefix 2>&1 | print_formatted_info "ZWELS" "prepare-instance.sh,global_validate:${LINENO}" -

  # currently node is always required
  # otherwise we should check if these services are starting:
  # - explorer-mvs, explorer-jes, explorer-uss
  # - app-server, zss
  validate_node_home 2>&1 | print_formatted_info "ZWELS" "prepare-instance.sh,global_validate:${LINENO}" -

  # validate java for some core components
  if [[ ${LAUNCH_COMPONENTS} == *"gateway"* || ${LAUNCH_COMPONENTS} == *"discovery"* || ${LAUNCH_COMPONENTS} == *"api-catalog"* || ${LAUNCH_COMPONENTS} == *"caching-service"* || ${LAUNCH_COMPONENTS} == *"files-api"* || ${LAUNCH_COMPONENTS} == *"jobs-api"* ]]; then
    validate_java_home 2>&1 | print_formatted_info "ZWELS" "prepare-instance.sh,global_validate:${LINENO}" -
  fi

  # validate z/OSMF for some core components
  if [ -n "${ZOSMF_HOST}" -a -n "${ZOSMF_PORT}" ]; then
    if [[ ${LAUNCH_COMPONENTS} == *"discovery"* || ${LAUNCH_COMPONENTS} == *"files-api"* || ${LAUNCH_COMPONENTS} == *"jobs-api"* ]]; then
      validate_zosmf_host_and_port "${ZOSMF_HOST}" "${ZOSMF_PORT}" 2>&1 | print_formatted_info "ZWELS" "prepare-instance.sh,global_validate:${LINENO}" -
    fi
  elif [ "${APIML_SECURITY_AUTH_PROVIDER}" = "zosmf" ]; then
    print_formatted_error "ZWELS" "prepare-instance.sh,global_validate:${LINENO}" "z/OSMF is not configured, APIML_SECURITY_AUTH_PROVIDER with value of zosmf is not supported."
    let "ERRORS_FOUND=${ERRORS_FOUND}+1"
  fi

  # Summary errors check, exit if errors found
  runtime_check_for_validation_errors_found

  print_formatted_info "ZWELS" "prepare-instance.sh,global_validate:${LINENO}" "global validations are successful"
}

########################################################
# Prepare workspace directory
prepare_workspace_dir() {
  print_formatted_info "ZWELS" "prepare-instance.sh,prepare_workspace_dir:${LINENO}" "prepare workspace directory ..."

  mkdir -p ${WORKSPACE_DIR}
  # Make accessible to group so owning user can edit?
  chmod -R 771 ${WORKSPACE_DIR} 1> /dev/null 2> /dev/null
  if [ "$?" != "0" ]; then
    print_formatted_error "ZWELS" "prepare-instance.sh,prepare_workspace_dir:${LINENO}" "permission of instance workspace directory (${WORKSPACE_DIR}) is not setup correctly"
    print_formatted_error "ZWELS" "prepare-instance.sh,prepare_workspace_dir:${LINENO}" "a proper configured workspace directory should allow group write permission to both Zowe runtime user and installation / configuration user(s)"
  fi

  # Copy manifest into WORKSPACE_DIR so we know the version for support enquiries/migration
  cp ${ROOT_DIR}/manifest.json ${WORKSPACE_DIR}

  # STATIC_DEF_CONFIG_DIR maybe not have a value if discovery is not started in this instance
  if [ -n "${STATIC_DEF_CONFIG_DIR}" ]; then
    # create static definition directory
    mkdir -p ${STATIC_DEF_CONFIG_DIR}
  fi
}

########################################################
# Validate component properties if script exists
validate_components() {
  print_formatted_info "ZWELS" "prepare-instance.sh,validate_components:${LINENO}" "process component validations ..."
  ERRORS_FOUND=0
  for component_id in $(echo "${LAUNCH_COMPONENTS}" | sed "s/,/ /g")
  do
    component_dir=$(find_component_directory "${component_id}")
    if [ -n "${component_dir}" ]; then
      cd "${component_dir}"

      # backward compatible purpose, some may expect this variable to be component lifecycle directory
      export LAUNCH_COMPONENT="${component_dir}/bin"

      # check validate script
      validate_script=$(read_component_manifest "${component_dir}" ".commands.validate" 2>/dev/null)
      if [ -z "${validate_script}" -o "${validate_script}" = "null" ]; then
        # backward compatible purpose
        if [ $(is_core_component "${component_dir}") != "true" ]; then
          print_formatted_warn "ZWELS" "prepare-instance.sh,validate_components:${LINENO}" "- unable to determine validate script from component ${component_id} manifest, fall back to default bin/validate.sh"
        fi
        validate_script=bin/validate.sh
      fi
      if [ -x "${validate_script}" ]; then
        print_formatted_debug "ZWELS" "prepare-instance.sh,validate_components:${LINENO}" "- process ${component_id} validate command ..."
        result=$(. ${INSTANCE_DIR}/bin/internal/read-instance.sh -i "${ZWELS_HA_INSTANCE_ID}" -o "${component_id}" && . ${validate_script})
        retval=$?
        if [ -n "${result}" ]; then
          if [ "${retval}" = "0" ]; then
            print_formatted_debug "ZWELS" "prepare-instance.sh,validate_components:${LINENO}" "${result}"
          else
            print_formatted_error "ZWELS" "prepare-instance.sh,validate_components:${LINENO}" "${result}"
          fi
        fi
        let "ERRORS_FOUND=${ERRORS_FOUND}+${retval}"
      fi
      if [ "$(is_on_zos)" = "false" ]; then
        zos_deps=$(read_component_manifest "${component_dir}" ".dependencies.zos" 2>/dev/null)
        if [ -n "${zos_deps}" ]; then
          print_formatted_warn "ZWELS" "prepare-instance.sh,validate_components:${LINENO}" "- ${component_id} depends on z/OS service(s). This dependency may require additional setup, please refer to the component documentation"
        fi
      fi
    fi
  done
  # exit if there are errors found
  runtime_check_for_validation_errors_found
  print_formatted_debug "ZWELS" "prepare-instance.sh,validate_components:${LINENO}" "component validations are successful"
}

########################################################
# Prepare workspace directory - manage active_configuration.cfg
# Note: this function only applies when user is using instance.env
store_config_archive() {
  mkdir -p ${WORKSPACE_DIR}/backups

  #Backup previous directory if it exists
  if [[ -f ${WORKSPACE_DIR}"/active_configuration.cfg" ]]
  then
    PREVIOUS_DATE=$(cat ${WORKSPACE_DIR}/active_configuration.cfg | grep CREATION_DATE | cut -d'=' -f2)
    mv ${WORKSPACE_DIR}/active_configuration.cfg ${WORKSPACE_DIR}/backups/backup_configuration.${PREVIOUS_DATE}.cfg
  fi

  # Create a new active_configuration.cfg properties file with all the parsed parmlib properties stored in it,
  NOW=$(date +"%y.%m.%d.%H.%M.%S")
  ZOWE_VERSION=$(cat ${ROOT_DIR}/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
  cp ${INSTANCE_DIR}/instance.env ${WORKSPACE_DIR}/active_configuration.cfg
  cat <<EOF >> ${WORKSPACE_DIR}/active_configuration.cfg

# === zowe-certificates.env
EOF
  cat ${KEYSTORE_DIRECTORY}/zowe-certificates.env >> ${WORKSPACE_DIR}/active_configuration.cfg
  cat <<EOF >> ${WORKSPACE_DIR}/active_configuration.cfg

# === extra information
VERSION=${ZOWE_VERSION}
CREATION_DATE=${NOW}
ROOT_DIR=${ROOT_DIR}
STATIC_DEF_CONFIG_DIR=${STATIC_DEF_CONFIG_DIR}
LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}
EOF
}

########################################################
# Run setup/configure on components if script exists
configure_components() {
  print_formatted_info "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "process component configurations ..."
  for component_id in $(echo "${LAUNCH_COMPONENTS}" | sed "s/,/ /g")
  do
    component_dir=$(find_component_directory "${component_id}")
    if [ -n "${component_dir}" ]; then
      cd "${component_dir}"

      # prepare component workspace
      component_name=$(basename "${component_dir}")
      mkdir -p "${ZWELS_INSTANCE_ENV_DIR}/${component_name}"

      # backward compatible purpose, some may expect this variable to be component lifecycle directory
      export LAUNCH_COMPONENT="${component_dir}/bin"

      print_formatted_debug "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "- configure ${component_id}"

      # default build-in behaviors
      # - apiml static definitions
      result=$(process_component_apiml_static_definitions "${component_dir}" 2>&1)
      retval=$?
      if [ -n "${result}" ]; then
        if [ "${retval}" = "0" ]; then
          print_formatted_debug "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "${result}"
        else
          print_formatted_error "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "${result}"
        fi
      fi
      # - desktop iframe plugin
      result=$(process_component_desktop_iframe_plugin "${component_dir}" 2>&1)
      retval=$?
      if [ -n "${result}" ]; then
        if [ "${retval}" = "0" ]; then
          print_formatted_debug "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "${result}"
        else
          print_formatted_error "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "${result}"
        fi
      fi
      # - generic app framework plugin
      result=$(process_component_appfw_plugin "${component_dir}" 2>&1)
      retval=$?
      if [ -n "${result}" ]; then
        if [ "${retval}" = "0" ]; then
          print_formatted_debug "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "${result}"
        else
          print_formatted_error "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "${result}"
        fi
      fi

      # check configure script
      configure_script=$(read_component_manifest "${component_dir}" ".commands.configure" 2>/dev/null)
      if [ -z "${configure_script}" -o "${configure_script}" = "null" ]; then
        # backward compatible purpose
        if [ $(is_core_component "${component_dir}") != "true" ]; then
          print_formatted_warn "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "* unable to determine configure script from component ${component_id} manifest, fall back to default bin/configure.sh"
        fi
        configure_script=bin/configure.sh
      fi
      if [ -x "${configure_script}" ]; then
        print_formatted_debug "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "* process ${component_id} configure command ..."
        # execute configure step and snapshot environment
        result=$(. ${INSTANCE_DIR}/bin/internal/read-instance.sh -i "${ZWELS_HA_INSTANCE_ID}" -o "${component_id}" && . ${configure_script} ; rc=$? ; export -p | grep -v -E '^export (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD=|PS1=|ENV=|_=)' > "${ZWELS_INSTANCE_ENV_DIR}/${component_name}/.${ZWELS_HA_INSTANCE_ID}.env" ; return $rc)
        retval=$?
        if [ -n "${result}" ]; then
          if [ "${retval}" = "0" ]; then
            print_formatted_debug "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "${result}"
          else
            print_formatted_error "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "${result}"
          fi
        fi
      fi
    fi
  done
  print_formatted_debug "ZWELS" "prepare-instance.sh,configure_components:${LINENO}" "component configurations are successful"
}

########################################################
# Parse command line parameters
OPTIND=1
while getopts "c:r:i:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    r) ROOT_DIR=${OPTARG};;
    i) ZWELS_HA_INSTANCE_ID=${OPTARG};;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

# export this to other scripts
export INSTANCE_DIR
# find runtime directory to locate the scripts
if [ -z "${ROOT_DIR}" ]; then
  # if this script is sourced, this may not return correct path
  # this value should be trustworthy since this script is not supposed to be sourced
  export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
  # validate if this is zowe root path
  if [ ! -f "${ROOT_DIR}/manifest.json" ]; then
    echo "ROOT_DIR is not defined. You can either pass the value with -r parameter or define it as global environment variable." >&2
    exit 1
  fi
fi

# source utility scripts
[ -z "$(is_instance_utils_sourced 2>/dev/null || true)" ] && . ${INSTANCE_DIR}/bin/internal/utils.sh
. ${INSTANCE_DIR}/bin/internal/read-essential-vars.sh
[ -z "$(is_runtime_utils_sourced 2>/dev/null || true)" ] && . ${ROOT_DIR}/bin/utils/utils.sh

# ignore default value passed from ZWESLSTC
if [ "${ZWELS_HA_INSTANCE_ID}" = "{{ha_instance_id}}" -o "${ZWELS_HA_INSTANCE_ID}" = "__ha_instance_id__" ]; then
  ZWELS_HA_INSTANCE_ID=
fi
# assign default value
if [ -z "${ZWELS_HA_INSTANCE_ID}" ]; then
  ZWELS_HA_INSTANCE_ID=$(get_sysname)
fi
# sanitize instance id
ZWELS_HA_INSTANCE_ID=$(echo "${ZWELS_HA_INSTANCE_ID}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/_/g')
export ZWELS_HA_INSTANCE_ID

# prepare some environment variables we always need
. ${ROOT_DIR}/bin/internal/zowe-set-env.sh
# display starting information
print_formatted_info "ZWELS" "prepare-instance.sh:${LINENO}" "starting Zowe instance ${ZWELS_HA_INSTANCE_ID} from ${INSTANCE_DIR} ..."
print_formatted_debug "ZWELS" "prepare-instance.sh:${LINENO}" "use configuration defined in ${ZWELS_CONFIG_LOAD_METHOD}"

# Fix node.js piles up in IPC message queue
if [ "$(is_on_zos)" = "true" ]; then
  ${ROOT_DIR}/scripts/utils/cleanup-ipc-mq.sh
fi

# init <instance>/.env directory and load environment variables
prepare_instance_env_directory
# global validations
global_validate
# prepare <instance>/workspace directory
prepare_workspace_dir

# FIXME: do we need to do similar if the user is using zowe.yaml?
if [ "${ZWELS_CONFIG_LOAD_METHOD}" = "instance.env" ]; then
  store_config_archive
fi
validate_components
configure_components

########################################################
# Keep config dir for zss within permissions it accepts
# FIXME: this should be moved to zlux/bin/configure.sh.
#        Ideally we want this removed entirely as it stops uses from being able 
#        to delete the instance directory and can cause errors on upgrade
if [ -d ${WORKSPACE_DIR}/app-server/serverConfig ]
then
  chmod 750 ${WORKSPACE_DIR}/app-server/serverConfig 1> /dev/null 2> /dev/null
  chmod_rc1=$?
  chmod -R 740 ${WORKSPACE_DIR}/app-server/serverConfig/* 1> /dev/null 2> /dev/null
  chmod_rc2=$?
  if [ "${chmod_rc1}" != "0" -o "${chmod_rc2}" != "0" ]; then
    print_formatted_error "ZWELS" "prepare-instance.sh:${LINENO}" "permission of app-server workspace directory (${WORKSPACE_DIR}/app-server/serverConfig) is not setup correctly"
    print_formatted_error "ZWELS" "prepare-instance.sh:${LINENO}" "a proper configured workspace directory should allow group write permission to both Zowe runtime user and installation / configuration user(s)"
  fi
fi

# display instance prepared info
print_formatted_info "ZWELS" "prepare-instance.sh:${LINENO}" "Zowe runtime environment prepared"
# display starting components information
print_formatted_debug "ZWELS" "prepare-instance:${LINENO}" "starting component(s) ${LAUNCH_COMPONENTS} ..."
