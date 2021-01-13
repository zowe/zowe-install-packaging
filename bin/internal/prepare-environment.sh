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

if [ "${ZWE_ENVIRONMENT_PREPARED}" = "true" ]; then
  # environment variables are already prepared, skip running
  return 0
fi

# export all variables defined in this script automatically
set -a

# initialize flag variable to avoid re-run this script
ZWE_ENVIRONMENT_PREPARED=

# if the user passes INSTANCE_DIR from command line parameter "-c"
while getopts "c:r:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    r) ROOT_DIR=${OPTARG};;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done

# validate INSTANCE_DIR which is required
if [[ -z ${INSTANCE_DIR} ]]; then
  echo "INSTANCE_DIR is not defined. You can either pass the value with -c parameter or define it as global environment variable." >&2
  exit 1
fi

# find runtime directory if it's not defined
if [ -z "${ROOT_DIR}" ]; then
  # if this script is sourced, this may not return correct path
  ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
  # validate if this is zowe root path
  if [ ! -f "${ROOT_DIR}/manifest.json" ]; then
    echo "ROOT_DIR is not defined. You can either pass the value with -r parameter or define it as global environment variable." >&2
    exit 1
  fi
fi

# prepare some environment variables we always need
. ${ROOT_DIR}/bin/internal/zowe-set-env.sh

# read the instance environment variables to make sure they exists
# Question: is there a better way to load these variables since this is already handled by
#           <instance-dir>/bin/internal/run-zowe.sh
. ${INSTANCE_DIR}/bin/internal/read-instance.sh
if [ -n "${KEYSTORE_DIRECTORY}" -a -f "${KEYSTORE_DIRECTORY}/zowe-certificates.env" ]; then
  . ${INSTANCE_DIR}/bin/internal/read-keystore.sh
fi

# this variable is used by Gateway to fetch Zowe version and build information
ZOWE_MANIFEST="${ROOT_DIR}/manifest.json"

# workspace directory variable
WORKSPACE_DIR=${INSTANCE_DIR}/workspace

# TODO - in for backwards compatibility, remove once naming conventions finalised and sorted #870
VERIFY_CERTIFICATES="${ZOWE_APIM_VERIFY_CERTIFICATES}"

LAUNCH_COMPONENTS=""
export ZOWE_PREFIX=${ZOWE_PREFIX}${ZOWE_INSTANCE}

# If ZWE_LAUNCH_COMPONENTS set it takes precedence over LAUNCH_COMPONENT_GROUPS
if [[ -n "${ZWE_LAUNCH_COMPONENTS}" ]]
then
  LAUNCH_COMPONENTS=${ZWE_LAUNCH_COMPONENTS}
else
  if [[ ${LAUNCH_COMPONENT_GROUPS} == *"GATEWAY"* ]]
  then
    LAUNCH_COMPONENTS=discovery,gateway,api-catalog,files-api,jobs-api,explorer-jes,explorer-mvs,explorer-uss
    if [[ -n ${ZOWE_CACHING_SERVICE_START} && ${ZOWE_CACHING_SERVICE_START} == true ]]
    then
      LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS},caching-service
    fi
  fi

  #Explorers may be present, but have a prereq on gateway, not desktop
  if [[ ${LAUNCH_COMPONENT_GROUPS} == *"DESKTOP"* ]]
  then
    LAUNCH_COMPONENTS=zss,app-server,${LAUNCH_COMPONENTS} #Make app-server the first component, so any extender plugins can use its config
    PLUGINS_DIR=${WORKSPACE_DIR}/app-server/plugins
  elif [[ ${LAUNCH_COMPONENT_GROUPS} == *"ZSS"* ]]
  then
    LAUNCH_COMPONENTS=zss,${LAUNCH_COMPONENTS}
  fi
fi

if [[ ${LAUNCH_COMPONENTS} == *"discovery"* ]]
then
  # Create the user configurable api-defs
  STATIC_DEF_CONFIG_DIR=${WORKSPACE_DIR}/api-mediation/api-defs
  mkdir -p ${STATIC_DEF_CONFIG_DIR}
fi

# Notes: changed old behavior
# Old behavior: LAUNCH_COMPONENTS is a list of full path to component lifecycle scripts folder
#LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}",${EXTERNAL_COMPONENTS}"
# New behavior: LAUNCH_COMPONENTS and EXTERNAL_COMPONENTS can be list of component IDs or paths
#               The other script may use `find_component_directory` function to find the component
#               root directory.
LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}",${EXTERNAL_COMPONENTS}"

# source all utility libraries
. ${ROOT_DIR}/bin/utils/utils.sh
# FIXME: ideally this should be handled by component configure.sh lifecycle script.
#        We may require extensions to have these code in conformance program.
# FIXME: prepare-environment.sh shouldn't have any output, but these 2 functions may output:
#        Prepending JAVA_HOME/bin to the PATH...
#        Prepending NODE_HOME/bin to the PATH...
#        so we surpressed all output for those 2 functions
if [ -n "${JAVA_HOME}" ]; then
  ensure_java_is_on_path 1>/dev/null 2>&1
fi
if [ -n "${NODE_HOME}" ]; then
  ensure_node_is_on_path 1>/dev/null 2>&1
fi

# set flag so we don't need to re-run this script
ZWE_ENVIRONMENT_PREPARED=true

# turn off automatic export
set +a
