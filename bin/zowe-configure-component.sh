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

#######################################################################
# Configure Zowe Component
#
# This script will configure a component for Zowe instance. The component to
# be installed can be a pax, zip or tar package, or a directory.
#
# Note: this script works better with NODE_HOME. But for backward compatible
#       purpose, NODE_HOME is not mandatory.
#
# Command line options:
# -c|--component-name required. component name.
# -i|--instance-dir   required. path to Zowe instance directory.
# -d|--target-dir     optional. directory where the component is installed.
#                     For Zowe core component, default value is
#                     ${ZOWE_ROOT_DIR}/components. For Zowe extensions,
#                     the script will check ZWE_EXTENSION_DIR if possible.
#                     Otherwise will fall back to ${DEFAULT_TARGET_DIR}.
# -k|--core           optional boolean. Whether this component is bundled
#                     into Zowe package.
# -l|--logs-dir        optional. path to logs directory.
# -f|--log-file       optional. write log to the file specified.
#######################################################################

#######################################################################
# Constants
DEFAULT_TARGET_DIR=/global/zowe/extensions

#######################################################################
# Prepare shell environment
if [ -z "${ZOWE_ROOT_DIR}" ]; then
  export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../;pwd)
fi
export ROOT_DIR="${ZOWE_ROOT_DIR}"

. ${ZOWE_ROOT_DIR}/bin/internal/zowe-set-env.sh

[ -z "$(is_runtime_utils_sourced 2>/dev/null || true)" ] && . ${ZOWE_ROOT_DIR}/bin/utils/utils.sh
# this utils usually be sourced from instance dir, but here we are too early
[ -z "$(is_instance_utils_sourced 2>/dev/null || true)" ] && . ${ZOWE_ROOT_DIR}/bin/instance/internal/utils.sh

# node is required for read_component_manifest
if [ -n "${NODE_HOME}" ]; then
  ensure_node_is_on_path
fi

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
        set_install_log_file "zowe-configure-component"
    else
        set_install_log_file_from_full_path "${LOG_FILE}"
        validate_log_file_not_in_root_dir "${LOG_FILE}" "${ZOWE_ROOT_DIR}"
    fi
}

enable_component(){
    commands_start=$(read_component_manifest "${component_path}" ".commands.start" 2>/dev/null)
    if [ "${commands_start}" != "null" ] && [ -n "${commands_start}" ] && [ "${IS_ZOWE_CORE}" = "false" ]; then
        # we only enable if extension has commands.start defined in manifest
        log_message "- enable ${COMPONENT_NAME} for instance ${INSTANCE_DIR}"
        # append to EXTERNAL_COMPONENTS
        if [ -e "${INSTANCE_DIR}/instance.env" ]; then
            update_zowe_instance_variable "EXTERNAL_COMPONENTS" "${COMPONENT_NAME}" "true"
        elif [ -e "${INSTANCE_DIR}/zowe.yaml" ]; then
            update_zowe_yaml_variable "components.${COMPONENT_NAME}.enabled" "true"
        fi
    fi
}

install_app_framework_plugin(){
    iterator_index=0
    appfw_plugin_path=$(read_component_manifest "${component_path}" ".appfwPlugins[${iterator_index}].path" 2>/dev/null)
    while [ "${appfw_plugin_path}" != "null" ] && [ -n "${appfw_plugin_path}" ]; do
        log_message "- install Zowe App Framework plugin"
        cd "${component_path}"
        # Uses install-app.sh in zowe-instance-dir to automatically set up the component onto zowe
        if [[ -n "${LOG_FILE}" ]] && [[ -w "${LOG_FILE}" ]]; then
            ${INSTANCE_DIR}/bin/install-app.sh "$(get_full_path ${appfw_plugin_path})" >> $LOG_FILE
        else
            ${INSTANCE_DIR}/bin/install-app.sh "$(get_full_path ${appfw_plugin_path})"
        fi
        iterator_index=`expr $iterator_index + 1`
        appfw_plugin_path=$(read_component_manifest "${component_path}" ".appfwPlugins[${iterator_index}].path" 2>/dev/null)
    done
}

configure_component(){
    commands_cfg_instance=$(read_component_manifest "${component_path}" ".commands.configureInstance" 2>/dev/null)
    if [ "${commands_cfg_instance}" != "null" ] && [ -n "${commands_cfg_instance}" ]; then
        log_message "- process commands.configureInstance defined in manifest"
        cd ${component_path}
        ./${commands_cfg_instance}
    fi
}

ensure_zwe_extension_dir() {
    # write ZWE_EXTENSION_DIR to instance.env
    if [ "${IS_ZOWE_CORE}" = "false" ]; then
        log_message "- ensure ZWE_EXTENSION_DIR is defined in instance.env"
        if [ -e "${INSTANCE_DIR}/instance.env" ]; then
            update_zowe_instance_variable "ZWE_EXTENSION_DIR" "${TARGET_DIR}" "false"
        elif [ -e "${INSTANCE_DIR}/zowe.yaml" ]; then
            update_zowe_yaml_variable "zowe.extensionDirectory" "${TARGET_DIR}"
        fi
    fi
}

#######################################################################
# Parse command line options
while [ $# -gt 0 ]; do #Checks for parameters
    arg="$1"
    case $arg in
        -c|--component-name) # component name
            shift
            COMPONENT_NAME=$1
            shift
        ;;
        -i|--instance_dir) #Represents the path to zowe's instance directory (optional)
            shift
            path=$(get_full_path "$1")
            validate_directory_is_accessible "${path}"
            if [[ $? -eq 0 ]]; then
                if [ -e "$path/instance.env" -o -e "$path/zowe.yaml" ]; then
                    INSTANCE_DIR=${path}
                else
                    error_handler "-i|--instance_dir: Given path is not a zowe instance directory"
                fi
            else
                error_handler "-i|--instance_dir: Given path is not a zowe instance directory or does not exist"
            fi
            shift
        ;;
        -k|--core)
            IS_ZOWE_CORE=true
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
        -f|--log-file) # write logs to target file if specified
            shift
            LOG_FILE=$1
            shift
        ;;
        *)
            error_handler "$1 is an invalid flag\ntry: zowe-configure-component.sh -c <COMPONENT_NAME> -i <ZOWE_INSTANCE_DIR>"
            shift
    esac
done

#######################################################################
# Check and sanitize valiables
if [ -z "${COMPONENT_NAME}" -o -z "${INSTANCE_DIR}" ]; then
    #Ensures that the required parameters are entered, otherwise exit the program
    error_handler "Missing parameters, try: zowe-configure-component.sh -c <COMPONENT_NAME> -i <ZOWE_INSTANCE_DIR>"
fi

if [ "${IS_ZOWE_CORE}" != "true" ]; then
    IS_ZOWE_CORE=false
fi

# assign default value for TARGET_DIR
if [ -z "${TARGET_DIR}" ]; then
    if [ "${IS_ZOWE_CORE}" = "false" ]; then
        if [ -n "${ZWE_EXTENSION_DIR}" ]; then
            zwe_extension_dir="${ZWE_EXTENSION_DIR}"
        elif [ -n "${INSTANCE_DIR}" ]; then #instance_dir exists
            if [ -e "${INSTANCE_DIR}/instance.env" ]; then
                zwe_extension_dir=$(read_zowe_instance_variable "ZWE_EXTENSION_DIR")
            elif [ -e "${INSTANCE_DIR}/zowe.yaml" ]; then
                zwe_extension_dir=$(read_zowe_yaml_variable ".zowe.extensionDirectory")
                if [ "${zwe_extension_dir}" = "null" ]; then
                    zwe_extension_dir=
                fi
            fi
        fi
        if [ -z "${zwe_extension_dir}" ]; then
            #Assigns TARGET_DIR to the default directory since it was not set to a specific directory
            TARGET_DIR=${DEFAULT_TARGET_DIR}
        else
            TARGET_DIR=${zwe_extension_dir}
        fi
    else
      TARGET_DIR=${ZOWE_ROOT_DIR}/components
    fi
fi
# validate TARGET_DIR
component_path=${TARGET_DIR}/${COMPONENT_NAME}
if [ ! -e "${component_path}" ]; then
    error_handler "${component_path} does not exist."
fi
if [ "${IS_ZOWE_CORE}" = "false" ]; then
    # TARGET_DIR should be same as ZWE_EXTENSION_DIR defined in instance.env
    zwe_extension_dir=
    if [ -e "${INSTANCE_DIR}/instance.env" ]; then
        zwe_extension_dir=$(read_zowe_instance_variable "ZWE_EXTENSION_DIR")
    elif [ -e "${INSTANCE_DIR}/zowe.yaml" ]; then
        zwe_extension_dir=$(read_zowe_yaml_variable ".zowe.extensionDirectory")
        if [ "${zwe_extension_dir}" = "null" ]; then
            zwe_extension_dir=
        fi
    fi
    if [ -n "${zwe_extension_dir}" -a "${TARGET_DIR}" != "${zwe_extension_dir}" ]; then
        error_handler "It's recommended to install all Zowe extensions into same directory. The recommended target directory is ZWE_EXTENSION_DIR (${ZWE_EXTENSION_DIR}) defined in Zowe instance.env."
    fi
fi

if [ -z "${LOG_FILE}" -a -z "${LOG_DIRECTORY}" -a -n "${INSTANCE_DIR}" ]; then
    LOG_DIRECTORY="${INSTANCE_DIR}/logs"
fi

#######################################################################
# Install

prepare_log_file

print_and_log_message "Configure Zowe component ${component_path} for instance ${INSTANCE_DIR}"

ensure_zwe_extension_dir
configure_component
# FIXME: this should be handled during zowe-configure-instance.sh, but temporarily moved to runtime configure-component step
if [ "${IS_ZOWE_CORE}" = "false" ]; then
    install_app_framework_plugin
fi
enable_component

#######################################################################
# Conclude
log_message "Zowe component ${COMPONENT_FILE} is configured successfully.\n"
