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

while getopts "c:" opt; do
  case $opt in
    c) INSTANCE_DIR=$OPTARG;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# export this to other scripts
export INSTANCE_DIR
# find runtime directory to locate the scripts
export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)

. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}"
. ${ROOT_DIR}/bin/internal/global-validate.sh -c "${INSTANCE_DIR}"

launch_components_list=$(${ROOT_DIR}/bin/internal/get-launch-components.sh -c "${INSTANCE_DIR}")
. ${ROOT_DIR}/bin/internal/prepare-workspace.sh -c "${INSTANCE_DIR}" -t "${launch_components_list}"

# FIXME: Zowe Launcher can take responsibility from here
for component_id in $(echo $launch_components_list | sed "s/,/ /g"); do
  . ${ROOT_DIR}/bin/internal/start-component.sh -c "${INSTANCE_DIR}" -t "${component_id}" &
done
