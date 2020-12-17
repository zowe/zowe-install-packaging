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

DEFAULT_TARGET_DIR=/opt/zowe/extensions

if [[ -z ${ZOWE_ROOT_DIR} ]]
then
  export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../;pwd)
fi

. ${ZOWE_ROOT_DIR}/bin/utils/utils.sh

error_handler(){
    print_error_message "$1"
    exit 1
}

enable_component(){
    update_zowe_instance_variable "EXTERNAL_COMPONENTS" "${COMPONENT_NAME}"

    log_message "Zowe component has been installed."
}

install_desktop_plugin(){

    log_message "Running ${INSTANCE_DIR}/bin/install-app.sh ${component_path}"
    # Uses install-app.sh in zowe-instance-dir to automatically set up the component onto zowe
    ${INSTANCE_DIR}/bin/install-app.sh ${component_path}

    log_message "Zowe component has been installed."
}

configure_component(){
    
    cd ${component_path}

    commands_cfg_instance=$(read_component_manifest ${component_path} ".commands.configureInstance") 2>/dev/null

    if [ ! "${commands_cfg_instance}" = "null" ] && [ -n ${commands_cfg_instance}]; then
        ./${commands_cfg_instance}
    fi

    desktop_plugin_path=$(read_component_manifest "${component_path}" ".desktopPlugin[].path") 2>/dev/null

    if [ ! "${desktop_plugin_path}" = "null" ] && [ -n ${desktop_plugin_path} ]; then
        install_desktop_plugin
    fi

    commands_start=$(read_component_manifest "${component_path}" ".commands.start") 2>/dev/null

    if [ ! "${commands_start}" = "null" ] && [ -n "${commands_start}" ] && [ ${IS_NATIVE} = false ]; then
        enable_component
    fi

}

while [ $# -gt 0 ]; do #Checks for parameters
    arg="$1"
    case $arg in
        -o|--component) #Represents the path pointed to the component's compressed file
            shift
            COMPONENT_NAME=$1
            shift
        ;;
        -i|--instance_dir) #Represents the path to zowe's instance directory (optional)
            shift
            path=$(get_full_path "$1")
            validate_directory_is_accessible "${path}"
            if [[ $? -eq 0 ]]; then
                validate_file_not_in_directory "${path}/instance.env" "${path}"
                if [[ $? -ne 0 ]]; then
                    INSTANCE_DIR=${path}
                else
                    error_handler "-i|--instance_dir: Given path is not a zowe instance directory"
                fi
            else
                error_handler "-i|--instance_dir: Given path is not a zowe instance directory or does not exist"
            fi
            shift
        ;;
        -n|--native)
            IS_NATIVE=true
            shift
        ;;
        -d|--target_dir) # Represents the path to the desired target directory to place the extensions (optional)
            shift
            TARGET_DIR=$(get_full_path "$1")
            shift
        ;;
        -l|--logs-dir) # Represents the path to the installation logs
            shift
            LOG_DIRECTORY=$1
            shift
        ;;
        *)
            error_handler "$1 is an invalid flag\ntry: zowe-configure-component.sh -o {COMPONENT_NAME} -i {ZOWE_INSTANCE_DIR}"
            shift
    esac
done

# This is to prepare JAVA_HOME environment
. ${ZOWE_ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}" -r "${ZOWE_ROOT_DIR}"

if [ -z ${TARGET_DIR} ]; then
    TARGET_DIR=${DEFAULT_TARGET_DIR}
fi

if [ -z ${IS_NATIVE} ]; then
    IS_NATIVE=false
fi

if [ -z ${LOG_DIRECTORY} ]; then
    LOG_DIRECTORY="${INSTANCE_DIR}/logs"
fi

if [ -d "${TARGET_DIR}/${COMPONENT_NAME}" ]; then
    component_path=${TARGET_DIR}/${COMPONENT_NAME}
else
    error_handler "${TARGET_DIR}/${COMPONENT_NAME} is not an existing extension."
fi

set_install_log_directory "${LOG_DIRECTORY}"
validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
set_install_log_file "install-component"

log_message "Zowe Root Directory: ${ZOWE_ROOT_DIR}"
log_message "Component Name: ${COMPONENT_NAME}"
log_message "Zowe Instance Directory: ${INSTANCE_DIR}"
log_message "Target Directory: ${TARGET_DIR}"
log_message "Native Extension: ${IS_NATIVE}"
log_message "Log Directory: ${LOG_DIRECTORY}"

configure_component