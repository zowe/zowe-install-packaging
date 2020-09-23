#!/bin/sh

SCRIPT_NAME="$(basename $0)"
EXTENSION_PATH=""
INSTANCE_DIR=""
TARGET_DIR=""
EXTENSION_NAME=""
INSTALL_TYPE=""

error_handler(){
    echo "$SCRIPT_NAME: $1" 1>&2
    exit 1
}

install_component(){
    cd $TARGET_DIR

    if [ ! -d "$EXTENSION_NAME" ]; then
        mkdir $EXTENSION_NAME
    else
        # Clean up the directory and make a new one
        rm -rf $EXTENSION_NAME
        mkdir $EXTENSION_NAME
    fi

    cd $EXTENSION_NAME

    pax -ppx -rf "$EXTENSION_PATH"

    npm install --only=prod

    # Validates the pax file is correctly configured when unpaxed
    if [ ! -d "$TARGET_DIR/$EXTENSION_NAME/bin" ] || [ ! -e "$TARGET_DIR/$EXTENSION_NAME/bin/start.sh" ]; then
        #error_handler "PAX file is not a zowe extension."
        error_handler "$EXTENSION_PATH: Invalid package"
    fi

    # Represents the current value of EXTERNAL_COMPONENT variable in instance.env
    EXT_COMP_VAL=$(eval "grep 'EXTERNAL_COMPONENTS' $INSTANCE_DIR/instance.env | cut -f2 -d= | cut -f1 -d#")

    # Must add backslash escapees or else sed command will not work in the next step
    EXTENSION_BIN_PATH=$(eval "echo "$TARGET_DIR/$EXTENSION_NAME/bin" | sed 's/\//\\\\\//g'")

    if [ "$EXT_COMP_VAL" = " " ]; then
        sed -e "s/EXTERNAL_COMPONENTS=/EXTERNAL_COMPONENTS=$EXTENSION_BIN_PATH/" $INSTANCE_DIR/instance.env > $INSTANCE_DIR/instance.env.tmp
        mv $INSTANCE_DIR/instance.env.tmp $INSTANCE_DIR/instance.env
    else
        # Ensures that the bin directory of the extension is included into the instance.env once (Avoids duplication if same extension is installed twice)
        if [[ $(grep 'EXTERNAL_COMPONENT' $INSTANCE_DIR/instance.env | grep $TARGET_DIR/$EXTENSION_NAME/bin) = "" ]]; then
            sed -e "s/EXTERNAL_COMPONENTS=/EXTERNAL_COMPONENTS=$EXTENSION_BIN_PATH,/" $INSTANCE_DIR/instance.env > $INSTANCE_DIR/instance.env.tmp
            mv $INSTANCE_DIR/instance.env.tmp $INSTANCE_DIR/instance.env
        fi
    fi

    echo "Zowe component has been installed."
}

install_desktop_plugin(){
    cd $TARGET_DIR

    if [ ! -d "$EXTENSION_NAME" ]; then
        mkdir $EXTENSION_NAME
    else
        # Clean up the directory and make a new one
        rm -rf $EXTENSION_NAME
        mkdir $EXTENSION_NAME
    fi

    cd $EXTENSION_NAME

    pax -ppx -rf "$EXTENSION_PATH"

    # Validates the pax file is correctly configured when unpaxed
    if [ ! -e "pluginDefinition.json" ]; then
        error_handler "$EXTENSION_PATH: Invalid package"
    fi

    # Uses install-app.sh in zowe-instance-dir to automatically set up the extension onto zowe
    $INSTANCE_DIR/bin/install-app.sh $TARGET_DIR/$EXTENSION_NAME

    echo "Zowe desktop plugin has been installed."
}

while [ $# -gt 0 ]; do #Checks for parameters
    arg="$1"
    case $arg in
        -e|--extension) #Represents the path pointed to the extension's pax file
        shift
        if [[ "$1" = *.pax ]]; then
            EXTENSION_PATH=$1
        else
            error_handler "-e|--extension: Given path is not a pax file or does not exist"
        fi
        shift
        ;;
        -i|--instance_dir) #Represents the path to zowe's instance directory 
        shift
        if [ -d "$1" ] && [ -e "$1/instance.env" ]; then
            INSTANCE_DIR=$1
        else
            error_handler "-i|--instance_dir: Given path is not a zowe instance directory or does not exist"
        fi
        shift
        ;;
        -d|--target_dir)
        shift
        TARGET_DIR=$1
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
        *)
        error_handler "$1 is an invalid flag\ntry: zowe-install-extensions.sh -e {PATH_TO_EXTENSION} -i {ZOWE_INSTANCE_DIR} -n {NAME_OF_EXTENSION} -t component|desktop-plugin"
    esac
done

if [ -z $EXTENSION_PATH ] || [ -z $INSTANCE_DIR ] || [ -z $EXTENSION_NAME ] || [ -z $INSTALL_TYPE ]; then
    #Ensures that the required parameters are entered, otherwise exit the program
    error_handler "Missing parameters, try: zowe-install-extensions.sh -e {PATH_TO_EXTENSION} -i {ZOWE_INSTANCE_DIR} -n {NAME_OF_EXTENSION} -t component|desktop-plugin"
fi

if [ -z $TARGET_DIR ]; then
    #Assigns TARGET_DIR to the default directory since it was not set to a specific directory
    TARGET_DIR="$INSTANCE_DIR/extensions"
fi

if [ ! -e $TARGET_DIR ]; then
    echo "Creating extensions folder at $TARGET_DIR"
    mkdir $TARGET_DIR
fi

if [[ $INSTALL_TYPE == "component" ]]; then
    install_component
else
    install_desktop_plugin
fi