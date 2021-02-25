#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2021
################################################################################

################################################################################
# This script will prepare Zowe workspace for Zowe Launcher.
################################################################################

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

# export this to other scripts
export INSTANCE_DIR
export ROOT_DIR

. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}"
. ${ROOT_DIR}/bin/internal/global-validate.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}"

launch_components_list=$(${ROOT_DIR}/bin/internal/get-launch-components.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}")
. ${ROOT_DIR}/bin/internal/prepare-workspace.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -t "${launch_components_list}"
