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
# - ROOT_DIR
# - <Anything else defined in instance.env and zowe-certificates.env>
################################################################################

# export all variables defined in this script automatically
set -a

if [ "${ZWE_ENVIRONMENT_PREPARED}" = "true" ]; then
  # environment variables are already prepared, skip running
  exit 0
fi

# initialize flag variable to avoid re-run this script
ZWE_ENVIRONMENT_PREPARED=

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
# New behavior: LAUNCH_COMPONENTS and EXTERNAL_COMPONENTS can be list of component IDs
#               The other script will find the component in this sequence:
#               - ${ROOT_DIR}/components/<component-id>
#               - ${ZWE_EXTENSION_DIR}/<component-id>
LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}",${EXTERNAL_COMPONENTS}"

# set flag so we don't need to re-run this script
ZWE_ENVIRONMENT_PREPARED=true
