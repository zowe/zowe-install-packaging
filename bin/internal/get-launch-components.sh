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
# This script will return the components defined to be started in this Zowe instance.
#
# This script take these parameters
# - c:    instance directory
# - r:    optional, root directory
# - i:    optional, HA instance ID. Default value is &SYSNAME.
#
# These environment variables can also be passed from environment.
# - INSTANCE_DIR
# - ROOT_DIR
# - ZWELS_HA_INSTANCE_ID
#
# Note:
# 1. This script requires instance directory prepared for runtime. So
#    bin/internal/prepare-instance.sh should have been executed.
# 2. This script will write component list to stdout. If there are any errors,
#    the message will be written to stderr.
################################################################################

# if the user passes INSTANCE_DIR from command line parameter "-c"
OPTIND=1
while getopts "c:r:i:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    r) ROOT_DIR=${OPTARG};;
    i) ZWELS_HA_INSTANCE_ID=${OPTARG};;
    \?)
      >&2 echo "Invalid option: -${OPTARG}"
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

# validate INSTANCE_DIR which is required
if [[ -z ${INSTANCE_DIR} ]]; then
  >&2 echo "INSTANCE_DIR is not defined. You can either pass the value with -c parameter or define it as global environment variable."
  exit 1
fi
if [ -z "${ROOT_DIR}" ]; then
  # if this script is sourced, this may not return correct path
  export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
  # validate if this is zowe root path
  if [ ! -f "${ROOT_DIR}/manifest.json" ]; then
    >&2 echo "ROOT_DIR is not defined. You can either pass the value with -r parameter or define it as global environment variable."
    exit 1
  fi
fi

# suppress any output to make sure this script only output LAUNCH_COMPONENTS
. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -i "${ZWELS_HA_INSTANCE_ID}" 1>/dev/null 2>&1
# display component list
echo "${LAUNCH_COMPONENTS}"
exit 0
