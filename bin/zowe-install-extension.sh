#!/bin/sh

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

unpax_to_target_dir(){
    log_message "Changing directory to $TARGET_DIR"

    cd $TARGET_DIR

    # using file-utils will print out an unnecessary output
    if [ ! -d "$EXTENSION_NAME" ]; then
        mkdir $EXTENSION_NAME
        log_message "Creating directory at $TARGET_DIR/$EXTENSION_NAME"
    else
        # Clean up the directory and make a new one
        rm -rf $EXTENSION_NAME
        mkdir $EXTENSION_NAME
    fi

    log_message "Changing directory to $TARGET_DIR/$EXTENSION_NAME"
    cd $EXTENSION_NAME

    log_message "Unpaxing file $EXTENSION_PAX_FILE"
    pax -ppx -rf "$EXTENSION_PAX_FILE"
}

install_component(){
    unpax_to_target_dir

    # Validates the pax file is correctly configured when unpaxed
    if [ ! -d "$TARGET_DIR/$EXTENSION_NAME/bin" ] || [ ! -e "$TARGET_DIR/$EXTENSION_NAME/bin/start.sh" ]; then
        #error_handler "PAX file is not a zowe extension."
        error_handler "$EXTENSION_PAX_FILE: Invalid package"
    fi

    # Represents the current value of EXTERNAL_COMPONENT variable in instance.env
    EXT_COMP_VAL=$(eval "grep 'EXTERNAL_COMPONENTS' $INSTANCE_DIR/instance.env | cut -f2 -d= | cut -f1 -d#")

    # Must add backslash escapees or else sed command will not work in the next step
    EXTENSION_BIN_PATH=$(eval "echo "$TARGET_DIR/$EXTENSION_NAME/bin" | sed 's/\//\\\\\//g'")

    if [ "$EXT_COMP_VAL" = " " ]; then
        sed -e "s/EXTERNAL_COMPONENTS=/EXTERNAL_COMPONENTS=$EXTENSION_BIN_PATH/" $INSTANCE_DIR/instance.env > $INSTANCE_DIR/instance.env.tmp
        mv $INSTANCE_DIR/instance.env.tmp $INSTANCE_DIR/instance.env
        log_message "Appending directory path containing component's life cycle scripts into the EXTERNAL_COMPONENTS variable in instance.env"
    else
        # Ensures that the bin directory of the extension is included into the instance.env once (Avoids duplication if same extension is installed twice)
        if [[ $(grep 'EXTERNAL_COMPONENT' $INSTANCE_DIR/instance.env | grep $TARGET_DIR/$EXTENSION_NAME/bin) = "" ]]; then
            sed -e "s/EXTERNAL_COMPONENTS=/EXTERNAL_COMPONENTS=$EXTENSION_BIN_PATH,/" $INSTANCE_DIR/instance.env > $INSTANCE_DIR/instance.env.tmp
            mv $INSTANCE_DIR/instance.env.tmp $INSTANCE_DIR/instance.env
            log_message "Appending directory path containing component's life cycle scripts into the EXTERNAL_COMPONENTS variable in instance.env"
        fi
    fi

    log_message "Zowe component has been installed."
}

install_desktop_plugin(){
    unpax_to_target_dir

    log_message "Running $INSTANCE_DIR/bin/install-app.sh $TARGET_DIR/$EXTENSION_NAME"
    # Uses install-app.sh in zowe-instance-dir to automatically set up the extension onto zowe
    $INSTANCE_DIR/bin/install-app.sh $TARGET_DIR/$EXTENSION_NAME

    log_message "Zowe desktop plugin has been installed."
}

while [ $# -gt 0 ]; do #Checks for parameters
    arg="$1"
    case $arg in
        -e|--extension) #Represents the path pointed to the extension's pax file
            shift
            path=$(get_full_path "$1")
            if [[ "$path" = *.pax ]]; then
                EXTENSION_PAX_FILE=$path
            else
                error_handler "-e|--extension: Given path is not a pax file or does not exist"
            fi
            shift
        ;;
        -i|--instance_dir) #Represents the path to zowe's instance directory 
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
        -d|--target_dir)
            shift
            TARGET_DIR=$(get_full_path "$1")
            shift
        ;;
        -n|--name) #Represents the name of the plugin/extension
            shift
            EXTENSION_NAME="$1"
            shift
        ;;
        -t|--type) #Represents the type of extension whether its a desktop plugin or web component
            shift
            if [[ $1 == "component" ]] || [[ $1 == "desktop-plugin" ]]; then
                INSTALL_TYPE=$1
            else
                error_handler "-t|--type: Invalid value, possible values are 'component' and 'desktop-plugin'"
            fi
            shift
        ;;
        -l|--logs-dir)
            shift
            LOG_DIRECTORY=$1
            shift
        ;;
        *)
            error_handler "$1 is an invalid flag\ntry: zowe-install-extensions.sh -e {PATH_TO_EXTENSION} -i {ZOWE_INSTANCE_DIR} -n {NAME_OF_EXTENSION} -t component|desktop-plugin"
            shift
    esac
done

if [ -z $EXTENSION_PAX_FILE ] || [ -z $INSTANCE_DIR ] || [ -z $EXTENSION_NAME ] || [ -z $INSTALL_TYPE ]; then
    #Ensures that the required parameters are entered, otherwise exit the program
    error_handler "Missing parameters, try: zowe-install-extensions.sh -e {PATH_TO_EXTENSION} -i {ZOWE_INSTANCE_DIR} -n {NAME_OF_EXTENSION} -t component|desktop-plugin"
fi

if [ -z $TARGET_DIR ]; then
    #Assigns TARGET_DIR to the default directory since it was not set to a specific directory
    TARGET_DIR="$INSTANCE_DIR/extensions"
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
set_install_log_file "install-extension"

log_message "Zowe Root Directory: $ZOWE_ROOT_DIR"
log_message "Path to Extension: $EXTENSION_PAX_FILE"
log_message "Zowe Instance Directory: $INSTANCE_DIR"
log_message "Target Directory: $TARGET_DIR"
log_message "Extension Name: $EXTENSION_NAME"
log_message "Extension Type: $INSTALL_TYPE"
log_message "Log Directory: $LOG_DIRECTORY"

if [[ $INSTALL_TYPE == "component" ]]; then
    log_message "<<Install Component>>"
    install_component
else
    log_message "<<Install Desktop Plugin>>"
    install_desktop_plugin
fi

. ${ZOWE_ROOT_DIR}/bin/internal/zowe-set-env.sh
