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
# This script will validate if the environment is well prepared to start Zowe.
#
# These environment variables should have already been loaded:
# - INSTANCE_DIR
#
# Note: the INSTANCE_DIR can be predefined as global variable, or can be passed
#       from command line "-c" parameter.
################################################################################

# if the user passes INSTANCE_DIR from command line parameter "-c"
while getopts "c:r:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    r) ROOT_DIR=${OPTARG};;
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
LOGGING_SCRIPT_NAME=global-validate.sh

print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "process global validations ..."

########################################################
if [[ "${USER}" == "IZUSVR" ]]
then
  print_formatted_warn "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "You are running the Zowe process under user id IZUSVR. This is not recommended and may impact your z/OS MF server negatively."
fi

# reset error counter
ERRORS_FOUND=0

# Fix node.js piles up in IPC message queue
# FIXME: where is the best place for this fix? Currently it's here because global-validate.sh script is supposed to run only once.
${ROOT_DIR}/scripts/utils/cleanup-ipc-mq.sh

# Make sure INSTANCE_DIR is accessible and writable to the user id running this
validate_directory_is_writable "${INSTANCE_DIR}"

# Validate keystore directory accessible
validate_directory_is_accessible "${KEYSTORE_DIRECTORY}"

# ZOWE_PREFIX shouldn't be too long
validate_zowe_prefix

# currently node is always required
# otherwise we should check if these services are starting:
# - explorer-mvs, explorer-jes, explorer-uss
# - app-server, zss
validate_node_home

# validate java for some core components
if [[ ${LAUNCH_COMPONENTS} == *"gateway"* || ${LAUNCH_COMPONENTS} == *"discovery"* || ${LAUNCH_COMPONENTS} == *"api-catalog"* || ${LAUNCH_COMPONENTS} == *"caching-service"* || ${LAUNCH_COMPONENTS} == *"files-api"* || ${LAUNCH_COMPONENTS} == *"jobs-api"* ]]; then
  validate_java_home
fi

# validate z/OSMF for some core components
if [[ ${LAUNCH_COMPONENTS} == *"discovery"* || ${LAUNCH_COMPONENTS} == *"files-api"* || ${LAUNCH_COMPONENTS} == *"jobs-api"* ]]; then
  validate_zosmf_host_and_port "${ZOSMF_HOST}" "${ZOSMF_PORT}"
fi

########################################################
# Summary errors check, exit if errors found
runtime_check_for_validation_errors_found

print_formatted_info "${LOGGING_SERVICE_ID}" "${LOGGING_SCRIPT_NAME}:${LINENO}" "global validations are successful"
