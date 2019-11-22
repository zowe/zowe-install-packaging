#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

checkForErrorsFound() {
  if [[ $ERRORS_FOUND > 0 ]]
  then
    # if -v passed in any validation failures abort
    if [[ ! -z "$VALIDATE_ABORTS" ]]
    then
      echo "$ERRORS_FOUND errors were found during validatation, please check the message, correct any properties required in ${ROOT_DIR}/scripts/internal/run-zowe.sh and re-launch Zowe"
      exit $ERRORS_FOUND
    fi
  fi
}

# If -v passed in any validation failure result in the script exiting, other they are logged and continue
while getopts "c:v" opt; do
  case $opt in
    c) INSTANCE_DIR=$OPTARG;;
    v)
      VALIDATE_ABORTS=1;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [[ -z ${INSTANCE_DIR} ]]
then
  echo "-c parameter not set. Please re-launch ensuring the INSTANCE paramater is passed into the job"
  exit 1
fi

export ROOT_DIR=$(cd $(dirname $0)/../../;pwd) #we are in <ROOT_DIR>/bin/internal/run-zowe.sh

# Make sure INSTANCE_DIR is accessible and writable to the user id running this
. ${ROOT_DIR}/scripts/utils/validate-directory-is-writable.sh ${INSTANCE_DIR}
checkForErrorsFound

# TODO think of a better name?
WORKSPACE_DIR=${INSTANCE_DIR}/workspace
mkdir -p ${WORKSPACE_DIR}

# Read in configuration
. ${INSTANCE_DIR}/bin/read-instance.sh
# TODO - in for backwards compatibility, remove once naming conventions finalised and sorted
ZOWE_APIM_GATEWAY_PORT=$GATEWAY_PORT
ZOWE_IPADDRESS=$ZOWE_IP_ADDRESS
ZOSMF_IP_ADDRESS=$ZOSMF_HOST
VERIFY_CERTIFICATES=$ZOWE_APIM_VERIFY_CERTIFICATES

LAUNCH_COMPONENTS=""
export ZOWE_PREFIX=${ZOWE_PREFIX}${ZOWE_INSTANCE}
ZOWE_DESKTOP=${ZOWE_PREFIX}DT


# Make sure Java and Node are available on the Path
. ${ROOT_DIR}/scripts/utils/configure-java.sh
. ${ROOT_DIR}/scripts/utils/configure-node.sh
checkForErrorsFound

# Workaround Fix for node 8.16.1 that requires compatability mode for untagged files
export __UNTAGGED_READ_MODE=V6


if [[ $LAUNCH_COMPONENT_GROUPS == *"GATEWAY"* ]]
then
  LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS},files-api,jobs-api,api-mediation,explorer-jes,explorer-mvs,explorer-uss #TODO this is WIP - component ids not finalised at the moment
fi

if [[ $LAUNCH_COMPONENTS == *"api-mediation"* ]]
then
  # Create the user configurable api-defs
  STATIC_DEF_CONFIG_DIR=${WORKSPACE_DIR}/api-mediation/api-defs
  mkdir -p ${STATIC_DEF_CONFIG_DIR}
fi

# Validate component properties if script exists
ERRORS_FOUND=0
for i in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  VALIDATE_SCRIPT=${ROOT_DIR}/components/${i}/bin/validate.sh
  if [[ -f ${VALIDATE_SCRIPT} ]]
  then
    . ${VALIDATE_SCRIPT}
    retval=$?
    let "ERRORS_FOUND=$ERRORS_FOUND+$retval"
  fi
done

checkForErrorsFound

mkdir -p ${WORKSPACE_DIR}/backups
# Make accessible to group so owning user can edit?
chmod -R 771 ${WORKSPACE_DIR}

#Backup previous directory if it exists
if [[ -f ${WORKSPACE_DIR}"/active_configuration.cfg" ]]
then
  PREVIOUS_DATE=$(cat ${WORKSPACE_DIR}/active_configuration.cfg | grep CREATION_DATE | cut -d'=' -f2)
  mv ${WORKSPACE_DIR}/active_configuration.cfg ${WORKSPACE_DIR}/backups/backup_configuration.${PREVIOUS_DATE}.cfg
fi

# Create a new active_configuration.cfg properties file with all the parsed parmlib properties stored in it,
NOW=$(date +"%y.%m.%d.%H.%M.%S")
ZOWE_VERSION=$(cat $ROOT_DIR/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
cp ${INSTANCE_DIR}/instance.env ${WORKSPACE_DIR}/active_configuration.cfg
cat <<EOF >> ${WORKSPACE_DIR}/active_configuration.cfg
VERSION=${ZOWE_VERSION}
CREATION_DATE=${NOW}
ROOT_DIR=${ROOT_DIR}
STATIC_DEF_CONFIG_DIR=${STATIC_DEF_CONFIG_DIR}
LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}
EOF

# Copy manifest into WORKSPACE_DIR so we know the version for support enquiries/migration
cp ${ROOT_DIR}/manifest.json ${WORKSPACE_DIR}

# Run setup/configure on components if script exists
for i in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  CONFIGURE_SCRIPT=${ROOT_DIR}/components/${i}/bin/configure.sh
  if [[ -f ${CONFIGURE_SCRIPT} ]]
  then
    . ${CONFIGURE_SCRIPT}
  fi
done

for i in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  . ${ROOT_DIR}/components/${i}/bin/start.sh
done


# Start the desktop
if [[ $LAUNCH_COMPONENT_GROUPS == *"DESKTOP"* ]]
then
  cd $ROOT_DIR/zlux-app-server/bin && _BPX_JOBNAME=$ZOWE_DESKTOP ./nodeCluster.sh --allowInvalidTLSProxy=true &
fi