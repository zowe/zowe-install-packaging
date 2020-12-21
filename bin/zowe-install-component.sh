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

echo "ZOWE_ROOT_DIR before=${ZOWE_ROOT_DIR}"

if [[ -z ${ZOWE_ROOT_DIR} ]]
then
  export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../;pwd)
fi

echo "ZOWE_ROOT_DIR after=${ZOWE_ROOT_DIR}"

. ${ZOWE_ROOT_DIR}/bin/utils/utils.sh

# This is to prepare JAVA_HOME environment to execute commands.install
#. ${ZOWE_ROOT_DIR}/bin/internal/prepare-environment.sh

error_handler(){
    print_error_message "$1"
    exit 1
}

extract_to_target_dir(){
    log_message "Changing directory to ${TARGET_DIR}"

    cd "${TARGET_DIR}"

    if [ -d "${COMPONENT_FILE}" ]; then
        log_message "Creating symbolic link to the extension's directory."
        ln -s "${COMPONENT_FILE}" temp-ext-dir

        log_message "Changing directory to ${TARGET_DIR}/temp-ext-dir"
        cd temp-ext-dir
    else
        # create temporary directory to lay down extension files in
        log_message "Creating temporary directory to extract extension files into."
        mkdir temp-ext-dir

        log_message "Changing directory to ${TARGET_DIR}/temp-ext-dir"
        cd temp-ext-dir

        log_message "extract file ${COMPONENT_FILE}"

        if [[ "$COMPONENT_FILE" = *.pax ]]; then
            pax -ppx -rf "$COMPONENT_FILE"
        elif [[ "$COMPONENT_FILE" = *.zip ]]; then
            jar xf "$COMPONENT_FILE"
        elif [[ "$COMPONENT_FILE" = *.tar ]]; then
            pax -z tar -xf "$COMPONENT_FILE"
        fi
    fi

    component_name=$(read_component_manifest "${TARGET_DIR}/temp-ext-dir" ".name") 2>/dev/null

    cd "${TARGET_DIR}"

    if [ -d "${component_name}" ]; then
        log_message "Extension already installed, re-installing."
        log_message "Removing folder ${component_name}."
        rm -rf "${component_name}"
    fi

    log_message "Renaming temporary directory to ${component_name}."
    mv temp-ext-dir "${component_name}"

}

while [ $# -gt 0 ]; do #Checks for parameters
    arg="$1"
    case $arg in
        -o|--component) #Represents the path pointed to the component's compressed file
            shift
            path=$(get_full_path "$1")
            if [[ "$path" = *.pax ]] || [[ "$path" = *.zip ]] || [[ "$path" = *.tar ]] || [[ -d "$path" ]]; then
                COMPONENT_FILE="${path}"
            else
                error_handler "-o|--component: Given path is not in a correct file format or does not exist"
            fi
            shift
        ;;
        -i|--instance_dir) #Represents the path to zowe's instance directory (optional)
            shift
            path=$(get_full_path "$1")
            validate_directory_is_accessible "$path"
            if [[ $? -eq 0 ]]; then
                validate_file_not_in_directory "$path/instance.env" "$path"
                if [[ $? -ne 0 ]]; then
                    INSTANCE_DIR="${path}"
                else
                    error_handler "-i|--instance_dir: Given path is not a zowe instance directory"
                fi
            else
                error_handler "-i|--instance_dir: Given path is not a zowe instance directory or does not exist"
            fi
            shift
        ;;
        -d|--target_dir) # Represents the path to the desired target directory to place the extensions (optional)
            shift
            TARGET_DIR=$(get_full_path "$1")
            shift
        ;;
        -n|--native)
            IS_NATIVE=true
            shift
        ;;
        -l|--logs-dir) # Represents the path to the installation logs
            shift
            LOG_DIRECTORY=$1
            shift
        ;;
        *)
            error_handler "$1 is an invalid flag\ntry: zowe-install-component.sh -o {PATH_TO_COMPONENT} -i {ZOWE_INSTANCE_DIR}"
            shift
    esac
done

if [ -z ${COMPONENT_FILE} ]; then
    #Ensures that the required parameters are entered, otherwise exit the program
    error_handler "Missing parameters, try: zowe-install-component.sh -e {PATH_TO_COMPONENT}"
fi

if [ -z ${IS_NATIVE} ]; then
    IS_NATIVE=false
fi

if [ "${IS_NATIVE}" = false ]; then
    if [ ! -z ${INSTANCE_DIR} ]; then #instance_dir exists
        zwe_extension_dir=$(eval "grep '^ZWE_EXTENSION_DIR=' ${INSTANCE_DIR}/instance.env | cut -f2 -d=")
    fi
    if [ -z ${TARGET_DIR} ]; then
        if [ -z ${zwe_extension_dir} ]; then
            #Assigns TARGET_DIR to the default directory since it was not set to a specific directory
            TARGET_DIR=${DEFAULT_TARGET_DIR}
        else
            TARGET_DIR=${zwe_extension_dir}
        fi
    else
        if [ -z ${zwe_extension_dir} ]; then
            echo "ZWE_EXTENSION_DIR=${TARGET_DIR}" >> ${INSTANCE_DIR}/instance.env
        else
            if [ ! "${TARGET_DIR}" = "${zwe_extension_dir}" ]; then
                error_handler "Target Directory value does not match with ZWE_EXTENSION_DIR value in instance.env."
            fi
        fi
    fi
    # Checks to see if target directory is inside zowe runtime
    validate_file_not_in_directory "${TARGET_DIR}" "${ZOWE_ROOT_DIR}"
    if [[ $? -ne 0 ]]; then
        error_handler "The specified target directory is located within zowe's runtime folder. Select another location for the target directory."
    fi
elif [ -z ${TARGET_DIR} ]; then
    TARGET_DIR=${ZOWE_ROOT_DIR}/components
fi

if [ ! -e ${TARGET_DIR} ]; then
    log_message "Creating extensions folder at ${TARGET_DIR}"
    mkdir ${TARGET_DIR}
fi

if [ -z ${LOG_DIRECTORY} ]; then
    LOG_DIRECTORY="${INSTANCE_DIR}/logs"
fi

set_install_log_directory "${LOG_DIRECTORY}"
validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
set_install_log_file "configure-component"

log_message "Zowe Root Directory: ${ZOWE_ROOT_DIR}"
log_message "Path to Component: ${COMPONENT_FILE}"
log_message "Zowe Instance Directory: ${INSTANCE_DIR}"
log_message "Target Directory: ${TARGET_DIR}"
log_message "Log Directory: ${LOG_DIRECTORY}"

# Extract the files of the extension into target directory
extract_to_target_dir

# Call commands.install if exists
commands_installL=$(read_component_manifest "${TARGET_DIR}/${component_name}" ".commands.install") 2>/dev/null
if [[ ! "${commands_install}" = "null" ]] && [[ ! -z ${commands_install} ]]; then
    cd "${component_name}"
    # run commands
    . $commands_install
fi

# Check for automated configuration
if [ ! -z ${INSTANCE_DIR} ]; then
    # CALL CONFIGURE COMPONENT SCRIPT
    if [ "${IS_NATIVE}" = false ]; then
        ${ZOWE_ROOT_DIR}/bin/zowe-configure-component.sh -o "${component_name}" -d "${TARGET_DIR}" -i "${INSTANCE_DIR}"
    else
        ${ZOWE_ROOT_DIR}/bin/zowe-configure-component.sh -o "${component_name}" -d "${TARGET_DIR}" -i "${INSTANCE_DIR}" -n
    fi
fi

. ${ZOWE_ROOT_DIR}/bin/internal/zowe-set-env.sh
