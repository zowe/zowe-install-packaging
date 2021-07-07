#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020, 2021
################################################################################

################################################################################
# This script will prepare all the environment variables required to start
# a Zowe component.
#
# This script take these parameters
# - c:    instance directory
# - o:    optional, one component ID. If this is specified, the component version
#         instance.env will be loaded. For backward compatible purpose, the
#         parameter can also be a directory to the component lifecycle script folder.
# - r:    optional, root directory
# - i:    optional, HA instance ID. Default value is &SYSNAME.
#
# These environment variables can also be passed from environment.
# - INSTANCE_DIR
# - ROOT_DIR
# - ZWELS_HA_INSTANCE_ID
################################################################################

# export all variables defined in this script automatically
set -a

# if the user passes INSTANCE_DIR from command line parameter "-c"
OPTIND=1
while getopts "c:r:i:o:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    r) ROOT_DIR=${OPTARG};;
    i) ZWELS_HA_INSTANCE_ID=${OPTARG};;
    o) ZWELS_START_COMPONENT_ID=${OPTARG};;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

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
# source all utility libraries
[ -z "$(is_instance_utils_sourced 2>/dev/null || true)" ] && . ${INSTANCE_DIR}/bin/internal/utils.sh
[ -z "$(is_runtime_utils_sourced 2>/dev/null || true)" ] && . ${ROOT_DIR}/bin/utils/utils.sh

# ignore default value passed from ZWESLSTC
if [ "${ZWELS_HA_INSTANCE_ID}" = "{{ha_instance_id}}" -o "${ZWELS_HA_INSTANCE_ID}" = "__ha_instance_id__" ]; then
  ZWELS_HA_INSTANCE_ID=
fi
# assign default value
if [ -z "${ZWELS_HA_INSTANCE_ID}" ]; then
  ZWELS_HA_INSTANCE_ID=$(get_sysname)
fi
# sanitize instance id
ZWELS_HA_INSTANCE_ID=$(echo "${ZWELS_HA_INSTANCE_ID}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/_/g')

# read the instance environment variables to make sure they exists
. ${INSTANCE_DIR}/bin/internal/read-instance.sh -i "${ZWELS_HA_INSTANCE_ID}" -o "${ZWELS_START_COMPONENT_ID}"
if [ "${ZWELS_CONFIG_LOAD_METHOD}" = "instance.env" -a -n "${KEYSTORE_DIRECTORY}" -a -f "${KEYSTORE_DIRECTORY}/zowe-certificates.env" ]; then
  . ${INSTANCE_DIR}/bin/internal/read-keystore.sh -i "${ZWELS_HA_INSTANCE_ID}" -o "${ZWELS_START_COMPONENT_ID}"
fi

# this variable is used by Gateway to fetch Zowe version and build information
ZOWE_MANIFEST="${ROOT_DIR}/manifest.json"

# workspace directory variable
WORKSPACE_DIR=${INSTANCE_DIR}/workspace

# TODO - in for backwards compatibility, remove once naming conventions finalised and sorted #870
VERIFY_CERTIFICATES="${ZOWE_APIM_VERIFY_CERTIFICATES}"
NONSTRICT_VERIFY_CERTIFICATES="${ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES}"

# ignore user settings and set this value to be false
# this configuration is deprecated and settings in instance.env will not affect how Zowe is starting
APIML_PREFER_IP_ADDRESS=false

LAUNCH_COMPONENTS=""
# FIXME: if ZOWE_INSTANCE is same as last character of ZOWE_PREFIX, it will never be appended
if [[ "${ZOWE_PREFIX}" != *"${ZOWE_INSTANCE}" ]]; then
  # FIXME: append ZOWE_INSTANCE and overwrite ZOWE_PREFIX is too confusing, it causes problem when we source this file multiple times
  export ZOWE_PREFIX=${ZOWE_PREFIX}${ZOWE_INSTANCE}
fi

# If ZWE_LAUNCH_COMPONENTS set it takes precedence over LAUNCH_COMPONENT_GROUPS
if [[ -n "${ZWE_LAUNCH_COMPONENTS}" ]]
then
  LAUNCH_COMPONENTS=${ZWE_LAUNCH_COMPONENTS}
else
  if [[ ${LAUNCH_COMPONENT_GROUPS} == *"GATEWAY"* ]]
  then
    LAUNCH_COMPONENTS=discovery,gateway,api-catalog,caching-service,files-api,jobs-api,explorer-jes,explorer-mvs,explorer-uss
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

# caching-service with VSAM persistent can only run on z/OS
# FIXME: should we let sysadmin to decide this?
if [ `uname` != "OS/390" -a "${ZWE_CACHING_SERVICE_PERSISTENT}" = "VSAM" ]; then
  # to avoid potential retries on starting caching-service, do not start caching-service
  LAUNCH_COMPONENTS=$(echo "${LAUNCH_COMPONENTS}" | sed -e 's#caching-service##' | sed -e 's#,,#,#')
fi

# directory for user configurable api-defs
STATIC_DEF_CONFIG_DIR=${WORKSPACE_DIR}/api-mediation/api-defs

# Notes: changed old behavior
# Old behavior: LAUNCH_COMPONENTS is a list of full path to component lifecycle scripts folder
#LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}",${EXTERNAL_COMPONENTS}"
# New behavior: LAUNCH_COMPONENTS and EXTERNAL_COMPONENTS can be list of component IDs or paths
#               The other script may use `find_component_directory` function to find the component
#               root directory.
LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}",${EXTERNAL_COMPONENTS}"

# FIXME: ideally this should be handled by component configure.sh lifecycle script.
#        We may require extensions to have these code in conformance program.
# prepare-environment.sh shouldn't have any output, but these 2 functions may output:
#   Prepending JAVA_HOME/bin to the PATH...
#   Prepending NODE_HOME/bin to the PATH...
# so we surpressed all output for those 2 functions
if [ -n "${JAVA_HOME}" ]; then
  ensure_java_is_on_path 1>/dev/null 2>&1
fi
if [ -n "${NODE_HOME}" ]; then
  ensure_node_is_on_path 1>/dev/null 2>&1
fi

# turn off automatic export
set +a
