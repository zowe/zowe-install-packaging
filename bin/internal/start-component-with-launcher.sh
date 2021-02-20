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
# This script will start a Zowe component from Zowe Launcher.
#
# This script take these parameters
# - c:    INSTANCE_DIR
# - r:    ROOT_DIR
# - o:    one component ID.
#
# Zowe Launcher may use this script to start a component, so there may no any
# environment variables prepared.
#
# For example:
# $ bin/internal/start-component-with-launcher.sh \
#        -c "/path/to/my/zowe/instance" \
#        -r "/path/to/my/zowe/root" \
#        -o "discovery"
################################################################################

# if the user passes INSTANCE_DIR from command line parameter "-c"
while getopts "c:r:o:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    r) ROOT_DIR=${OPTARG};;
    o) component_id=${OPTARG};;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done


. ${ROOT_DIR}/bin/internal/zowe-set-env.sh
. ${ROOT_DIR}/bin/utils/utils.sh
. ${ROOT_DIR}/bin/internal/start-component.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -o "${component_id}"
