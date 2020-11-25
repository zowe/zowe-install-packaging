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
# This script will start a Zowe component.
#
# This script take these parameters
# - c:    INSTANCE_DIR
# - t:    one component ID. For backward compatible purpose, the parameter can
#         also be a directory to the component lifecycle script folder.
#
# Zowe Launcher may use this script to start a component, so there may no any
# environment variables prepared.
#
# For example:
# $ bin/internal/start-component.sh \
#        -c "/path/to/my/zowe/instance" \
#        -t "discovery"
################################################################################

# if the user passes INSTANCE_DIR from command line parameter "-c"
while getopts "c:t:" opt; do
  case $opt in
    c) INSTANCE_DIR=$OPTARG;;
    t) component_id=$OPTARG;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

########################################################
# prepare environment variables
export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}"

########################################################
# find component root directory and execute start script
component_dir=$(find_component_directory "${component_id}")
# backward compatible purpose, some may expect this variable to be component lifecycle directory
export LAUNCH_COMPONENT="${component_dir}/bin"
# FIXME: change here to read manifest `commands.start` entry
START_SCRIPT=${component_dir}/bin/start.sh
if [ ! -z "${component_dir}" -a -x "${START_SCRIPT}" ]; then
  . ${START_SCRIPT}
fi
