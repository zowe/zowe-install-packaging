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
# This script will start Zowe.
################################################################################

# If -v passed in any validation failure result in the script exiting, other they are logged and continue
while getopts "c:v" opt; do
  case $opt in
    c) INSTANCE_DIR=$OPTARG;;
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

# export this to other scripts
export INSTANCE_DIR
# find runtime directory
export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)

. ${ROOT_DIR}/bin/internal/prepare-environment.sh
. ${ROOT_DIR}/bin/internal/global-validate.sh

LAUNCH_COMPONENTS=$(${ROOT_DIR}/bin/internal/get-launch-components.sh)
. ${ROOT_DIR}/bin/internal/prepare-workspace.sh "${LAUNCH_COMPONENTS}"

# FIXME: Zowe Launcher can take responsibility from here
for LAUNCH_COMPONENT in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  . ${ROOT_DIR}/bin/internal/start-component.sh "${LAUNCH_COMPONENTS}" &
done
