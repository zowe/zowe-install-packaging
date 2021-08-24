#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2020
#######################################################################

#######################################################################
# Verify Zowe Component
#
# This script will verify a component of a Zowe instance.
#
#
# Command line options:
# -c|--component-id required. Identification of a component.
# -i|--instance-dir required. path to Zowe instance directory.
# -u|--username     required. Username of a specified user for the current system.
# -p|--password     required. Password of the specified user.
#######################################################################

#######################################################################
# Prepare shell environment
if [ -z "${ZOWE_ROOT_DIR}" ]; then
  export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../;pwd)
fi

if [ ! -f "${ZOWE_ROOT_DIR}/manifest.json" ]; then
    error_handler "ZOWE_ROOT_DIR path is not a zowe root directory."
fi

. ${ZOWE_ROOT_DIR}/bin/internal/zowe-set-env.sh

. ${ZOWE_ROOT_DIR}/bin/utils/utils.sh

#######################################################################
# Functions
error_handler(){
    print_error_message "$1"
    exit 1
}

prepare_log_file() {
    if [ -z "${LOG_FILE}" ]; then
        set_install_log_directory "${LOG_DIRECTORY}"
        validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
        set_install_log_file "zowe-verify-component"
    else
        set_install_log_file_from_full_path "${LOG_FILE}"
        validate_log_file_not_in_root_dir "${LOG_FILE}" "${ZOWE_ROOT_DIR}"
    fi
}

while [ $# -gt 0 ]; do #Checks for parameters
    arg="$1"
    case $arg in
        -c|--component-id) # component name
            shift
            component_id=$1
            shift
        ;;
        -u|--username)
            shift
            export VERIFY_USER_NAME=$1
            shift
        ;;
        -p|--password)
            shift
            export VERIFY_PASSWORD=$1
            shift
        ;;
        -i|--instance-dir)
            shift
            path=$(get_full_path "$1")
            validate_directory_is_accessible "$path"
            if [[ $? -eq 0 ]]; then
                validate_file_not_in_directory "$path/instance.env" "$path"
                if [[ $? -ne 0 ]]; then
                    INSTANCE_DIR="${path}"
                else
                    error_handler "-i|--instance-dir: Given path is not a zowe instance directory"
                fi
            else
                error_handler "-i|--instance-dir: Given path is not a zowe instance directory or does not exist"
            fi
            shift
        ;;
        -l|--logs-dir) # Represents the path to the installation logs
            shift
            LOG_DIRECTORY=$1
            shift
        ;;
        -f|--log-file) # write logs to target file if specified
            shift
            LOG_FILE=$1
            shift
        ;;
        *)
            error_handler "usage: zowe-verify-component.sh -c <component-id> -i <zowe-instance-dir> -r <zowe-root-dir>"
            shift
    esac
done

if [ -z "${INSTANCE_DIR}" ]; then
    error_handler "-i|--instance-dir - Instance directory must be assigned."
fi

if [ -z "${component_id}" ]; then
    error_handler "-c|--component-id - Component id must be assigned."
fi

if [ -z "${LOG_FILE}" -a -z "${LOG_DIRECTORY}" -a -n "${INSTANCE_DIR}" ]; then
    LOG_DIRECTORY="${INSTANCE_DIR}/logs"
fi

prepare_log_file

. ${ZOWE_ROOT_DIR}/bin/internal/prepare-environment.sh -c ${INSTANCE_DIR} -r ${ZOWE_ROOT_DIR}

print_and_log_message "Verify ${component_id} is started and registered on the Zowe instance."

verify_component_instance ${component_id}
rc=$?

if [[ $rc -eq 0 ]]; then
    print_and_log_message "Verification for ${component_id} was successful."
else
    print_and_log_message "Verification for ${component_id} was unsuccessful, there were ${rc} failure(s)."
fi

exit $rc
