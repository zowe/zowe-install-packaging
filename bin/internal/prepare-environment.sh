#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

################################################################################
# This script will prepare all the environment required to start a component.
#
# These environment variables should have already been loaded:
# - INSTANCE_DIR
#
# Note: the INSTANCE_DIR can be predefined as global variable, or can be passed
#       from command line "-c" parameter.
#
# Note: this script doesn't rely on <instance-dir>/bin/internal/run-zowe.sh, so
#       it assumes all environment variables in `instance.env` are not loaded.
#       With this assumption, we can safely call this script in Zowe Launcher
#       which doesn't have the environment prepared by run-zowe.sh.
#
# Note: this script could be called multiple times during start up.
################################################################################

# export all variables defined in this script automatically
set -a

if [ "${ZWE_ENVIRONMENT_PREPARED}" = "true" ]; then
  # environment variables are already prepared, skip running
  exit 0
fi

# initialize flag variable to avoid re-run this script
ZWE_ENVIRONMENT_PREPARED=

# if the user passes INSTANCE_DIR from command line parameter "-c"
while getopts "c:" opt; do
  case $opt in
    c) INSTANCE_DIR=$OPTARG;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# validate INSTANCE_DIR which is required
if [[ -z ${INSTANCE_DIR} ]]; then
  echo "INSTANCE_DIR is not defined. You can either pass the value with -c parameter or define it as global environment variable." >&2
  exit 1
fi

# find runtime directory
ROOT_DIR=$(cd $(dirname $0)/../../;pwd)

# read the instance environment variables to make sure they exists
# Question: is there a better way to load these variables since this is already handled by
#           <instance-dir>/bin/internal/run-zowe.sh
. ${INSTANCE_DIR}/bin/internal/read-instance.sh
if [ ! -z "${KEYSTORE_DIRECTORY}" -a -f "${KEYSTORE_DIRECTORY}/zowe-certificates.env" ]; then
  . ${INSTANCE_DIR}/bin/internal/read-keystore.sh
fi

. ${ROOT_DIR}/bin/internal/zowe-set-env.sh

# TODO think of a better name?
WORKSPACE_DIR=${INSTANCE_DIR}/workspace

# TODO - in for backwards compatibility, remove once naming conventions finalised and sorted #870
ZOWE_APIM_GATEWAY_PORT=$GATEWAY_PORT
ZOWE_IPADDRESS=$ZOWE_IP_ADDRESS
ZOSMF_IP_ADDRESS=$ZOSMF_HOST
VERIFY_CERTIFICATES=$ZOWE_APIM_VERIFY_CERTIFICATES
ZOWE_NODE_HOME=$NODE_HOME
ZOWE_JAVA_HOME=$JAVA_HOME

# zip #1226 - 1.10 -> 1.9 backward compatibility - default keystore type if not supplied
if [[ -z ${KEYSTORE_TYPE} ]]
then
  KEYSTORE_TYPE="PKCS12"
fi

LAUNCH_COMPONENTS=""
export ZOWE_PREFIX=${ZOWE_PREFIX}${ZOWE_INSTANCE}
ZOWE_DESKTOP=${ZOWE_PREFIX}DT

# Make sure Java and Node are available on the Path
. ${ROOT_DIR}/scripts/utils/configure-java.sh
if [[ ${SKIP_NODE} != 1 ]]
then
  . ${ROOT_DIR}/scripts/utils/configure-node.sh
fi

# If ZWE_LAUNCH_COMPONENTS set it takes precedence over LAUNCH_COMPONENT_GROUPS
if [[ -n "${ZWE_LAUNCH_COMPONENTS}" ]]
then
  LAUNCH_COMPONENTS=${ZWE_LAUNCH_COMPONENTS}
else
  if [[ $LAUNCH_COMPONENT_GROUPS == *"GATEWAY"* ]]
  then
    LAUNCH_COMPONENTS=api-mediation,files-api,jobs-api,explorer-jes,explorer-mvs,explorer-uss
  fi

  #Explorers may be present, but have a prereq on gateway, not desktop
  if [[ $LAUNCH_COMPONENT_GROUPS == *"DESKTOP"* ]]
  then
    LAUNCH_COMPONENTS=zss,app-server,${LAUNCH_COMPONENTS} #Make app-server the first component, so any extender plugins can use its config
    PLUGINS_DIR=${WORKSPACE_DIR}/app-server/plugins
  elif [[ $LAUNCH_COMPONENT_GROUPS == *"ZSS"* ]]
  then
    LAUNCH_COMPONENTS=zss,${LAUNCH_COMPONENTS}
  fi
fi

if [[ $LAUNCH_COMPONENTS == *"api-mediation"* ]]
then
  # Create the user configurable api-defs
  STATIC_DEF_CONFIG_DIR=${WORKSPACE_DIR}/api-mediation/api-defs
  mkdir -p ${STATIC_DEF_CONFIG_DIR}
fi

# Prepend directory path to all internal components
INTERNAL_COMPONENTS=""
for i in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  INTERNAL_COMPONENTS=${INTERNAL_COMPONENTS}",${ROOT_DIR}/components/${i}/bin"
done

# Notes: changed old behavior
# Old behavior: LAUNCH_COMPONENTS is a list of full path to component lifecycle scripts folder
#LAUNCH_COMPONENTS=${INTERNAL_COMPONENTS}",${EXTERNAL_COMPONENTS}"
# New behavior: LAUNCH_COMPONENTS and EXTERNAL_COMPONENTS can be list of component IDs or paths
#               The other script may use `find_component_directory` function to find the component
#               root directory.
LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}",${EXTERNAL_COMPONENTS}"

###############################
# Find component root directory
#
# This function will find the component in this sequence:
#   - ${ROOT_DIR}/components/<component-id>
#   - ${ZWE_EXTENSION_DIR}/<component-id>
#
# @param string     component id, or path to component lifecycle scripts
# Output            component directory will be written to stdout
find_component_directory() {
  component_id=$1
  # find component lifecycle scripts directory
  component_dir=
  if [ -d "${component_id}" ]; then
    component_lifecycle_dir=$component_id
    if [[ $component_lifecycle_dir == */bin ]]; then
      # the lifecycle dir ends with /bin, we assume the component root directory is one level up
      component_dir=$(cd ${component_lifecycle_dir}/../;pwd)
    else
      parent_dir=$(cd ${component_lifecycle_dir}/../;pwd)
      if [ -f "${parent_dir}/manifest.yaml" -o -f "${parent_dir}/manifest.yml" -o -f "${parent_dir}/manifest.json" ]; then
        # parent directory has manifest file, we assume it's Zowe component manifest and that's the root folder
        component_dir="${parent_dir}"
      fi
    fi
  else
    if [ -d "${ROOT_DIR}/components/${component}" ]; then
      # this is a Zowe build-in component
      component_dir="${ROOT_DIR}/components/${component}"
    elif [ ! -z "${ZWE_EXTENSION_DIR}" ]; then
      if [ -d "${ZWE_EXTENSION_DIR}/${component}" ]; then
        # this is an extension installed/linked in ZWE_EXTENSION_DIR
        component_dir="${ZWE_EXTENSION_DIR}/${component}"
      fi
    fi
  fi

  echo "$component_dir"
}

###############################
# Check if there are errors registered
#
# Notes: any error should increase global variable ERRORS_FOUND by 1.
checkForErrorsFound() {
  if [[ $ERRORS_FOUND > 0 ]]; then
    echo "$ERRORS_FOUND errors were found during validatation, please check the message, correct any properties required in ${INSTANCE_DIR}/instance.env and re-launch Zowe"
    exit $ERRORS_FOUND
  fi
}

# set flag so we don't need to re-run this script
ZWE_ENVIRONMENT_PREPARED=true
