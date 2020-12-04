#!/bin/sh
DEFAULT_TARGET_DIR=/opt/zowe/extensions

if [[ -z ${ZOWE_ROOT_DIR} ]]
then
  export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../;pwd)
fi

# Try and source the file utils if it exists
if [[ -f "${ZOWE_ROOT_DIR}/bin/utils/file-utils.sh" ]]
then
    . ${ZOWE_ROOT_DIR}/bin/utils/file-utils.sh
fi

error_handler(){
    print_error_message "$1"
    exit 1
}

extract_to_target_dir(){
    log_message "Changing directory to $TARGET_DIR"

    cd $TARGET_DIR

    if [ -d "$COMPONENT_FILE" ]; then
        log_message "Creating symbolic link to the extension's directory."
        ln -s $COMPONENT_FILE temp-ext-dir

        log_message "Changing directory to $TARGET_DIR/temp-ext-dir"
        cd temp-ext-dir
    else
        # create temporary directory to lay down extension files in
        log_message "Creating temporary directory to extract extension files into."
        mkdir temp-ext-dir

        log_message "Changing directory to $TARGET_DIR/temp-ext-dir"
        cd temp-ext-dir

        log_message "extract file $COMPONENT_FILE"

        if [[ "$COMPONENT_FILE" = *.pax ]]; then
            pax -ppx -rf "$COMPONENT_FILE"
        elif [[ "$COMPONENT_FILE" = *.zip ]]; then
            jar xf "$COMPONENT_FILE"
        elif [[ "$COMPONENT_FILE" = *.tar ]]; then
            pax -z tar -xf "$COMPONENT_FILE"
        fi
    fi

    # Locate manifest file
    if [[ -f "manifest.yaml" ]]; then
        MANIFEST_FILE="manifest.yaml"
    elif [[ -f "manifest.yml" ]]; then
        MANIFEST_FILE="manifest.yml"
    elif [[ -f "manifest.json" ]]; then
        MANIFEST_FILE="manifest.json"
    fi

    if [ ! -z $MANIFEST_FILE ]; then
        COMPONENT_NAME=$(eval "java -jar ${ZOWE_ROOT_DIR}/bin/utils/format-converter-cli.jar $TARGET_DIR/temp-ext-dir/$MANIFEST_FILE | java -jar ${ZOWE_ROOT_DIR}/bin/utils/jackson-jq-cli.jar -r '.name'")
    fi

    cd $TARGET_DIR

    if [ -d "$COMPONENT_NAME" ]; then
        log_message "Extension already installed, re-installing."
        log_message "Removing folder $COMPONENT_NAME."
        rm -rf $COMPONENT_NAME
    fi

    MANIFEST_PATH=$TARGET_DIR/$COMPONENT_NAME/$MANIFEST_FILE

    log_message "Renaming temporary directory to $COMPONENT_NAME."
    mv temp-ext-dir $COMPONENT_NAME

    # Call commands.install if exists
    COMMANDS_INSTALL=$(eval "java -jar ${ZOWE_ROOT_DIR}/bin/utils/format-converter-cli.jar $MANIFEST_PATH | java -jar ${ZOWE_ROOT_DIR}/bin/utils/jackson-jq-cli.jar -r '.commands.install'")
    if [[ ! $COMMANDS_INSTALL = "null" ]]; then
        cd $COMPONENT_NAME
        # run commands
        ./$COMMANDS_INSTALL
    fi
}

while [ $# -gt 0 ]; do #Checks for parameters
    arg="$1"
    case $arg in
        -o|--component) #Represents the path pointed to the component's compressed file
            shift
            path=$(get_full_path "$1")
            if [[ "$path" = *.pax ]] || [[ "$path" = *.zip ]] || [[ "$path" = *.tar ]] || [[ -d "$path" ]]; then
                COMPONENT_FILE=$path
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
                    INSTANCE_DIR=$path
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

if [ -z $COMPONENT_FILE ]; then
    #Ensures that the required parameters are entered, otherwise exit the program
    error_handler "Missing parameters, try: zowe-install-component.sh -e {PATH_TO_COMPONENT}"
fi

if [ -z $TARGET_DIR ]; then
    if [ ! -z $INSTANCE_DIR ]; then #instance_dir exists
        ZWE_EXTENSION_DIR=$(eval "grep '^ZWE_EXTENSION_DIR=' $INSTANCE_DIR/instance.env | cut -f2 -d=")
    fi
    if [ -z $ZWE_EXTENSION_DIR ]; then
        #Assigns TARGET_DIR to the default directory since it was not set to a specific directory
        TARGET_DIR=$DEFAULT_TARGET_DIR
    else
        TARGET_DIR=$ZWE_EXTENSION_DIR
    fi
fi

# Checks to see if target directory is inside zowe runtime
validate_file_not_in_directory "$TARGET_DIR" "$ZOWE_ROOT_DIR"
if [[ $? -ne 0 ]]; then
    error_handler "The specified target directory is located within zowe's runtime folder. Select another location for the target directory."
fi

if [ ! -e $TARGET_DIR ]; then
    log_message "Creating extensions folder at $TARGET_DIR"
    mkdir $TARGET_DIR
fi

if [ -z $LOG_DIRECTORY ]; then
    LOG_DIRECTORY="$INSTANCE_DIR/logs"
fi

. ${ZOWE_ROOT_DIR}/bin/utils/setup-log-dir.sh
set_install_log_directory "${LOG_DIRECTORY}"
validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
set_install_log_file "configure-component"

log_message "Zowe Root Directory: $ZOWE_ROOT_DIR"
log_message "Path to Component: $COMPONENT_FILE"
log_message "Zowe Instance Directory: $INSTANCE_DIR"
log_message "Target Directory: $TARGET_DIR"
log_message "Log Directory: $LOG_DIRECTORY"

# Extract the files of the extension into target directory
extract_to_target_dir

# Check for automated configuration
if [ ! -z $INSTANCE_DIR ]; then
    # CALL CONFIGURE COMPONENT SCRIPT
    ${ZOWE_ROOT_DIR}/bin/zowe-configure-component.sh -o $COMPONENT_NAME -d $TARGET_DIR -i $INSTANCE_DIR
fi

. ${ZOWE_ROOT_DIR}/bin/internal/zowe-set-env.sh
