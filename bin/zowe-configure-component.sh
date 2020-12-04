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

install_component(){

    # Represents the current value of EXTERNAL_COMPONENT variable in instance.env
    EXT_COMP_VAL=$(eval "grep '^EXTERNAL_COMPONENTS=' $INSTANCE_DIR/instance.env | cut -f2 -d= | cut -f1 -d#")

    if [ "$EXT_COMP_VAL" = " " ]; then
        sed -e "s/EXTERNAL_COMPONENTS=/EXTERNAL_COMPONENTS=$COMPONENT_NAME/" $INSTANCE_DIR/instance.env > $INSTANCE_DIR/instance.env.tmp
        mv $INSTANCE_DIR/instance.env.tmp $INSTANCE_DIR/instance.env
        log_message "Appending directory path containing component's life cycle scripts into the EXTERNAL_COMPONENTS variable in instance.env"
    else
        # Ensures that the bin directory of the component is included into the instance.env once (Avoids duplication if same component is installed twice)
        if [[ $(grep 'EXTERNAL_COMPONENT' $INSTANCE_DIR/instance.env | grep $COMPONENT_NAME) = "" ]]; then
            sed -e "s/EXTERNAL_COMPONENTS=/EXTERNAL_COMPONENTS=$COMPONENT_NAME,/" $INSTANCE_DIR/instance.env > $INSTANCE_DIR/instance.env.tmp
            mv $INSTANCE_DIR/instance.env.tmp $INSTANCE_DIR/instance.env
            log_message "Appending directory path containing component's life cycle scripts into the EXTERNAL_COMPONENTS variable in instance.env"
        fi
    fi

    log_message "Zowe component has been installed."
}

install_desktop_plugin(){

    log_message "Running $INSTANCE_DIR/bin/install-app.sh $COMPONENT_PATH"
    # Uses install-app.sh in zowe-instance-dir to automatically set up the component onto zowe
    $INSTANCE_DIR/bin/install-app.sh $COMPONENT_PATH

    log_message "Zowe component has been installed."
}

configure_component(){

    cd $COMPONENT_PATH

    if [[ -f "$COMPONENT_PATH/manifest.yaml" ]]; then
        MANIFEST_PATH="$COMPONENT_PATH/manifest.yaml"
    elif [[ -f "$COMPONENT_PATH/manifest.yml" ]]; then
        MANIFEST_PATH="$COMPONENT_PATH/manifest.yml"
    elif [[ -f "$COMPONENT_PATH/manifest.json" ]]; then
        MANIFEST_PATH="$COMPONENT_PATH/manifest.json"
    fi

    COMMANDS_CFG_INSTANCE=$(eval "java -jar ${ZOWE_ROOT_DIR}/bin/utils/format-converter-cli.jar $MANIFEST_PATH | java -jar ${ZOWE_ROOT_DIR}/bin/utils/jackson-jq-cli.jar -r '.commands.configureInstance'")

    if [ ! "$COMMANDS_CFG_INSTANCE" = "null" ]; then
        ./$COMMANDS_CFG_INSTANCE
    fi

    DESKTOP_PLUGIN=$(eval "java -jar ${ZOWE_ROOT_DIR}/bin/utils/format-converter-cli.jar $MANIFEST_PATH | java -jar ${ZOWE_ROOT_DIR}/bin/utils/jackson-jq-cli.jar -r '.desktopPlugin'")

    if [ ! "$DESKTOP_PLUGIN" = "null" ]; then
            DESKTOP_PLUGIN_PATH=$(eval "java -jar ${ZOWE_ROOT_DIR}/bin/utils/format-converter-cli.jar $MANIFEST_PATH | java -jar ${ZOWE_ROOT_DIR}/bin/utils/jackson-jq-cli.jar -r '.desktopPlugin[].path'")
            if [ ! "$DESKTOP_PLUGIN_PATH" = "null" ]; then
                install_desktop_plugin
            fi
    fi

    COMMANDS_START=$(eval "java -jar ${ZOWE_ROOT_DIR}/bin/utils/format-converter-cli.jar $MANIFEST_PATH | java -jar ${ZOWE_ROOT_DIR}/bin/utils/jackson-jq-cli.jar -r '.commands.start'")

    if [ ! "$COMMANDS_START" = "null" ] && [ $IS_NATIVE = false ]; then
        install_component
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
        -n|--native)
            shift
            IS_NATIVE=$1
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

if [ -z $TARGET_DIR ]; then
    TARGET_DIR=$DEFAULT_TARGET_DIR
fi

if [ -z $IS_NATIVE ]; then
    IS_NATIVE=false
fi

if [ -z $LOG_DIRECTORY ]; then
    LOG_DIRECTORY="$INSTANCE_DIR/logs"
fi

if [ -d "$TARGET_DIR/$COMPONENT_NAME" ]; then
    COMPONENT_PATH=$TARGET_DIR/$COMPONENT_NAME
else
    error_handler "$TARGET_DIR/$COMPONENT_NAME is not an existing extension."
fi

. ${ZOWE_ROOT_DIR}/bin/utils/setup-log-dir.sh
set_install_log_directory "${LOG_DIRECTORY}"
validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
set_install_log_file "install-component"

log_message "Zowe Root Directory: $ZOWE_ROOT_DIR"
log_message "Component Name: $COMPONENT_NAME"
log_message "Zowe Instance Directory: $INSTANCE_DIR"
log_message "Target Directory: $TARGET_DIR"
log_message "Log Directory: $LOG_DIRECTORY"

configure_component