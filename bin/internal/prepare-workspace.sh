#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

################################################################################
# This script will run component `validate` and `configure` step if they are defined.
#
# This script take these parameters
# - c:    INSTANCE_DIR
# - t:    a list of component IDs or paths to component lifecycle script directory
#         separated by comma
#
# For example:
# $ bin/internal/prepare-workspace.sh \
#        -c "/path/to/my/zowe/instance" \
#        -t "discovery,explorer-jes,jobs"
################################################################################

# if the user passes INSTANCE_DIR from command line parameter "-c"
while getopts "c:r:t:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    r) ROOT_DIR=${OPTARG};;
    t) LAUNCH_COMPONENTS=${OPTARG};;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done

########################################################
# prepare environment variables
if [ -z "${ROOT_DIR}" ]; then
  # if this script is sourced, this may not return correct path
  export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
  # validate if this is zowe root path
  if [ ! -f "${ROOT_DIR}/manifest.json" ]; then
    echo "ROOT_DIR is not defined. You can either pass the value with -r parameter or define it as global environment variable." >&2
    exit 1
  fi
fi
. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}"

# zowe launch script logging identifier
LOGGING_SERVICE_ID=ZWELS
LOGGING_SCRIPT_NAME=prepare-workspace.sh

########################################################
# Prepare workspace directory
prepare_workspace_dir() {
  print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "prepare workspace directory ..."
  mkdir -p ${WORKSPACE_DIR}
  # Make accessible to group so owning user can edit?
  chmod -R 771 ${WORKSPACE_DIR}

  # Copy manifest into WORKSPACE_DIR so we know the version for support enquiries/migration
  cp ${ROOT_DIR}/manifest.json ${WORKSPACE_DIR}
}

########################################################
# convert components YAML manifest to JSON format
convert_component_yaml_to_json() {
  print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "prepare component manifest in workspace ..."
  for component_id in $(echo "${LAUNCH_COMPONENTS}" | sed "s/,/ /g")
  do
    component_dir=$(find_component_directory "${component_id}")
    if [ -n "${component_dir}" ]; then
      print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "- ${component_id}"
      convert_component_manifest "${component_dir}"
    fi
  done
  print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "component manifests prepared"
}

########################################################
# Validate component properties if script exists
validate_components() {
  print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "process component validations ..."
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
        print_formatted_warn "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "- unable to determine validate script from component ${component_id} manifest, fall back to default bin/validate.sh"
        validate_script=bin/validate.sh
      fi
      if [ -x "${validate_script}" ]; then
        print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "- process ${component_id} validate command ..."
        result=$(. ${validate_script})
        retval=$?
        if [ -n "${result}" ]; then
          if [ "${retval}" = "0" ]; then
            print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${result}"
          else
            print_formatted_error "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${result}"
          fi
        fi
        let "ERRORS_FOUND=${ERRORS_FOUND}+${retval}"
      fi
    fi
  done
  # exit if there are errors found
  runtime_check_for_validation_errors_found
  print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "component validations are successful"
}

########################################################
# Prepare workspace directory - manage active_configuration.cfg
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
  print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "process component configurations ..."
  for component_id in $(echo "${LAUNCH_COMPONENTS}" | sed "s/,/ /g")
  do
    component_dir=$(find_component_directory "${component_id}")
    if [ -n "${component_dir}" ]; then
      cd "${component_dir}"

      # backward compatible purpose, some may expect this variable to be component lifecycle directory
      export LAUNCH_COMPONENT="${component_dir}/bin"

      print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "- configure ${component_id}"

      # default build-in behaviors
      # - apiml static definitions
      result=$(process_component_apiml_static_definitions "${component_dir}" 2>&1)
      retval=$?
      if [ -n "${result}" ]; then
        if [ "${retval}" = "0" ]; then
          print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${result}"
        else
          print_formatted_error "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${result}"
        fi
      fi
      # - desktop iframe plugin
      result=$(process_component_desktop_iframe_plugin "${component_dir}" 2>&1)
      retval=$?
      if [ -n "${result}" ]; then
        if [ "${retval}" = "0" ]; then
          print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${result}"
        else
          print_formatted_error "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${result}"
        fi
      fi

      # check configure script
      configure_script=$(read_component_manifest "${component_dir}" ".commands.configure" 2>/dev/null)
      if [ -z "${configure_script}" -o "${configure_script}" = "null" ]; then
        # backward compatible purpose
        print_formatted_warn "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "* unable to determine configure script from component ${component_id} manifest, fall back to default bin/configure.sh"
        configure_script=bin/configure.sh
      fi
      if [ -x "${configure_script}" ]; then
        print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "* process ${component_id} configure command ..."
        result=$(. ${configure_script})
        retval=$?
        if [ -n "${result}" ]; then
          if [ "${retval}" = "0" ]; then
            print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${result}"
          else
            print_formatted_error "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "${result}"
          fi
        fi
      fi
    fi
  done
  print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "component configurations are successful"
}

########################################################
# prepare workspace
prepare_workspace_dir
convert_component_yaml_to_json
validate_components
store_config_archive
configure_components

########################################################
# Keep config dir for zss within permissions it accepts
# FIXME: this should be moved to zlux/bin/configure.sh.
#        Ideally we want this removed entirely as it stops uses from being able 
#        to delete the instance directory and can cause errors on upgrade
if [ -d ${WORKSPACE_DIR}/app-server/serverConfig ]
then
  chmod 750 ${WORKSPACE_DIR}/app-server/serverConfig
  chmod -R 740 ${WORKSPACE_DIR}/app-server/serverConfig/*
fi

