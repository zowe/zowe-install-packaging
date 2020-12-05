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
# This script will return the components defined to be started in this Zowe instance.
#
# These environment variables should have already been loaded:
# - INSTANCE_DIR
#
# Note: the INSTANCE_DIR can be predefined as global variable, or can be passed
#       from command line "-c" parameter.
################################################################################

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
if [ -z "${ROOT_DIR}" ]; then
  # if this script is sourced, this may not return correct path
  export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
  # validate if this is zowe root path
  if [ ! -f "${ROOT_DIR}/manifest.json" ]; then
    echo "ROOT_DIR is not defined. You can either pass the value with -r parameter or define it as global environment variable." >&2
    exit 1
  fi
fi

# suppress any output to make sure this script only output LAUNCH_COMPONENTS
. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" 1> /dev/null 2>&1
echo "${LAUNCH_COMPONENTS}"
