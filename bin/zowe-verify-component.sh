#!/bin/sh

# Temporary, this script needs to be fixed up 

while [ $# -gt 0 ]; do #Checks for parameters
    arg="$1"
    case $arg in
        -c|--component-id) # component name
            shift
            component_id=$1
            shift
        ;;
        -i|--instance_dir)
            shift
            INSTANCE_DIR=$1
            shift
        ;;
        -r|--root_dir)
            shift
            ROOT_DIR=$1
            shift
        ;;
        *)
            echo "usage: zowe-verify-component.sh -c <component-id> -i <zowe-instance-dir> -r <zowe-root-dir>"
            shift
    esac
done

if [ -z "${INSTANCE_DIR}" ]; then
    echo "-i|--instance_dir - Instance directory must be assigned."
    exit 1
fi

if [ -z "${ROOT_DIR}" ]; then
    echo "-r|--root_dir - Root directory must be assigned."
    exit 1
fi

if [ -z "${component_id}" ]; then
    echo "-c|--component-id - Component id must be assigned."
    exit 1
fi

. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c ${INSTANCE_DIR} -r ${ROOT_DIR}

verify_component_instance ${component_id}