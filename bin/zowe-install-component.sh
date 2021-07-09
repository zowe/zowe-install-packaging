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
# Zowe Component Installer
#
# This script will install a component into target directory. The component to
# be installed can be a pax, zip or tar package, or a directory.
#
# Note: this script works better with NODE_HOME. But for backward compatible
#       purpose, NODE_HOME is not mandatory.
#
# Command line options:
# -c|--component-name optional. component name. If NODE_HOME is defined, and the
#                     component has manifest, this value is optional. Otherwise
#                     it's required.
# -o|--component-file required. path to the component package or directory.
# -i|--instance-dir   optional. path to Zowe instance directory. If this
#                     has a value, the script will also execute
#                     zowe-configure-component.sh.
# -d|--target-dir     optional. path to target directory. For core component,
#                     default value is ${ZOWE_ROOT_DIR}/components. For Zowe
#                     extensions, the script will check ZWE_EXTENSION_DIR
#                     if possible. Otherwise will fall back to
#                     ${DEFAULT_TARGET_DIR}.
# -e|--auto-encoding  optional. If we want to automatically tagging the
#                     directory. Default value is "auto". Allowed values are:
#                     - yes: automatically tag the files encoding
#                     - no: do not automatically tag encoding
#                     - auto: only tag when manifest is in ISO8859-1 encoding.
#                     This option is only applicable for z/OS.
# -k|--core           optional boolean. Whether this component is bundled
#                     into Zowe package.
# -l|--logs-dir       optional. path to logs directory.
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

# is on z/OS?
RUN_ON_ZOS=$(test `uname` = "OS/390" && echo "true")

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
        set_install_log_file "zowe-install-component"
    else
        set_install_log_file_from_full_path "${LOG_FILE}"
        validate_log_file_not_in_root_dir "${LOG_FILE}" "${ZOWE_ROOT_DIR}"
    fi
}

extract_to_target_dir(){
    cd "${TARGET_DIR}" && rm -fr temp-ext-dir

    if [ -d "${COMPONENT_FILE}" ]; then
        log_message "- component is a directory, create symbolic link to target directory."
        ln -s "${COMPONENT_FILE}" temp-ext-dir
    else
        # create temporary directory to lay down extension files in
        mkdir -p temp-ext-dir && cd temp-ext-dir

        log_message "- extract file $(basename ${COMPONENT_FILE}) to temporary directory."

        if [[ "$COMPONENT_FILE" = *.pax ]]; then
            pax -ppx -rf "$COMPONENT_FILE"
        elif [[ "$COMPONENT_FILE" = *.zip ]]; then
            jar xf "$COMPONENT_FILE"
        elif [[ "$COMPONENT_FILE" = *.tar ]]; then
            _CEE_RUNOPTS="FILETAG() POSIX(ON)" pax -x tar -rf "$COMPONENT_FILE"
        fi
    fi

    # automatically tag files
    if [ "${RUN_ON_ZOS}" = "true" ]; then
        manifest_encoding=$(detect_component_manifest_encoding "${TARGET_DIR}/temp-ext-dir")
        log_message "Component manifest encoding=${manifest_encoding}, requested auto_encoding=${AUTO_ENCODING}"
        #the autotag script we have is for tagging when files are ascii, so we assume tagging cant be done unless ascii
        autotag="no"

        if [ "${manifest_encoding}" = "ISO8859-1" ]; then
            is_tagged=$(detect_if_component_tagged "${TARGET_DIR}/temp-ext-dir")
            # unless explicitly asked to tag, if component is already tagged, retag could produce errors
            if [ "${is_tagged}" = "true" ]; then
                log_message "Component tagged, so turning auto-encoding off"
                autotag="no"
            else
                log_message "ASCII Component not tagged, so turning auto-encoding ON"
                autotag="yes"
            fi
        fi
        if [ "${AUTO_ENCODING}" != "no" -a "${autotag}" = "yes" ]; then
            # automatically tag files
            log_message "- automatically tag files"
            $ZOWE_ROOT_DIR/scripts/utils/tag-files.sh "${TARGET_DIR}/temp-ext-dir" 1>&2 >> $LOG_FILE
            cd "${TARGET_DIR}/temp-ext-dir"
            log_message "- files in $(pwd) after tagged"
            ls -TREal >> $LOG_FILE
        fi
    fi

    if [ -n "${COMPONENT_NAME}" ]; then
        component_name="${COMPONENT_NAME}"
    else
        component_name=$(read_component_manifest "${TARGET_DIR}/temp-ext-dir" ".name" 2>/dev/null)
        if [ -z "${component_name}" -o "${component_name}" = "null" ]; then
            rm -fr "${TARGET_DIR}/temp-ext-dir"
            error_handler "Cannot find component name from package manifest. -c|--component-name is required."
        fi
    fi

    cd "${TARGET_DIR}"

    if [ -e "${component_name}" ]; then
        rm -fr temp-ext-dir
        error_handler "Component ${component_name} already exists in ${TARGET_DIR}."
    fi

    log_message "- rename temporary directory to ${component_name}."
    mv temp-ext-dir "${component_name}"

}

process_command_install() {
    if [ -z "${NODE_HOME}" ]; then
        error_handler "NODE_HOME is not defined. The component commands.install defined in manifest will not be processed.
You can either re-run the zowe-install-component.sh script with NODE_HOME defined, or run commands.install defined in manifest manually."
    else
        commands_install=$(read_component_manifest "${TARGET_DIR}/${component_name}" ".commands.install" 2>/dev/null)
        if [[ "${commands_install}" != "null" ]] && [[ -n "${commands_install}" ]]; then
            log_message "- process ${commands_install} defined in manifest commands.install"
            cd "${TARGET_DIR}/${component_name}"
            # run commands
            . $commands_install
        fi
    fi
}

configure_component() {
    if [ -n "${INSTANCE_DIR}" ]; then
        # CALL CONFIGURE COMPONENT SCRIPT
        cmd="${ZOWE_ROOT_DIR}/bin/zowe-configure-component.sh"
        cmd="${cmd} -c \"${component_name}\""
        cmd="${cmd} -d \"${TARGET_DIR}\""
        cmd="${cmd} -i \"${INSTANCE_DIR}\""
        # we should always have LOG_FILE at this time
        cmd="${cmd} -f \"${LOG_FILE}\""
        if [ "${IS_ZOWE_CORE}" = "true" ]; then
          cmd="${cmd} -k"
        fi
        eval "${cmd}"
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
        -o|--component-file) #Represents the path pointed to the component's compressed file
            shift
            path=$(get_full_path "$1")
            if [ -a "$path" ]; then
                if [[ "$path" = *.pax ]] || [[ "$path" = *.zip ]] || [[ "$path" = *.tar ]] || [[ -d "$path" ]]; then
                    COMPONENT_FILE="${path}"
                else
                    error_handler "-o|--component-file: Given path is not in a correct file format"
                fi
            else
                error_handler "-o|--component-file: Given path does not exist"
            fi
            shift
        ;;
        -i|--instance-dir) #Represents the path to zowe's instance directory (optional)
            shift
            path=$(get_full_path "$1")
            validate_directory_is_accessible "$path"
            if [[ $? -eq 0 ]]; then
                if [ -e "$path/instance.env" -o -e "$path/zowe.yaml" ]; then
                    INSTANCE_DIR="${path}"
                else
                    error_handler "-i|--instance-dir: Given path is not a zowe instance directory"
                fi
            else
                error_handler "-i|--instance-dir: Given path is not a zowe instance directory or does not exist"
            fi
            shift
        ;;
        -d|--target-dir) # Represents the path to the desired target directory to place the extensions (optional)
            shift
            TARGET_DIR=$(get_full_path "$1")
            shift
        ;;
        -k|--core)
            IS_ZOWE_CORE=true
            shift
        ;;
        -e|--auto-encoding)
            shift
            AUTO_ENCODING=$1
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
            error_handler "$1 is an invalid option\ntry: zowe-install-component.sh -o <PATH_TO_COMPONENT>"
            shift
    esac
done

#######################################################################
# Check and sanitize valiables
if [ -z "${COMPONENT_FILE}" ]; then
    #Ensures that the required parameters are entered, otherwise exit the program
    error_handler "Missing parameters, try: zowe-install-component.sh -o <PATH_TO_COMPONENT>"
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
if [ "${IS_ZOWE_CORE}" = "false" ]; then
    # install extensions into Zowe runtime directory is not allowed.
    validate_file_not_in_directory "${TARGET_DIR}" "${ZOWE_ROOT_DIR}"
    if [[ $? -ne 0 ]]; then
        error_handler "The specified target directory is located within zowe's runtime folder. Select another location for the target directory."
    fi
    if [ -n "${INSTANCE_DIR}" ]; then #instance_dir exists
        # install extensions into instance workspace directory is not suggested.
        validate_file_not_in_directory "${TARGET_DIR}" "${INSTANCE_DIR}/workspace"
        if [[ $? -ne 0 ]]; then
            print_error_message "WARNING: the specified target directory is located within zowe's instance workspace folder, this is not recommended."
        fi

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
fi

if [ -n "${COMPONENT_NAME}" ]; then
    # exit early, but similar check will be done again later if COMPONENT_NAME is not defined
    if [ -e "${TARGET_DIR}/${COMPONENT_NAME}" ]; then
        error_handler "Component ${COMPONENT_NAME} already exists in ${TARGET_DIR}."
    fi
fi

if [ "${AUTO_ENCODING}" != "no" -a "${AUTO_ENCODING}" != "yes" ]; then
  AUTO_ENCODING=auto
fi

if [ -z "${LOG_FILE}" -a -z "${LOG_DIRECTORY}" -a -n "${INSTANCE_DIR}" ]; then
    LOG_DIRECTORY="${INSTANCE_DIR}/logs"
fi

#######################################################################
# Install

prepare_log_file

print_and_log_message "Install Zowe component ${COMPONENT_FILE} to ${TARGET_DIR}"

# prepare target directory
mkdir -p "${TARGET_DIR}"
validate_directory_is_writable "${TARGET_DIR}"
if [[ $? -ne 0 ]]; then
    error_handler "Target directory ${TARGET_DIR} is not writable."
fi

# Extract the files of the extension into target directory
extract_to_target_dir
# component_name should have been assigned value in extract_to_target_dir

# Call commands.install if exists
process_command_install

# Check for automated configuration if INSTANCE_DIR is defined
configure_component

#######################################################################
# Conclude
log_message "Zowe component ${component_name} is installed successfully.\n"
