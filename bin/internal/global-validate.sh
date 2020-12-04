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
# This script will validate if the environment is well prepared to start Zowe.
#
# These environment variables should have already been loaded:
# - INSTANCE_DIR
#
# Note: the INSTANCE_DIR can be predefined as global variable, or can be passed
#       from command line "-c" parameter.
################################################################################

# if the user passes INSTANCE_DIR from command line parameter "-c"
while getopts "c:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done

########################################################
# prepare environment variables
export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}"

########################################################
if [[ "${USER}" == "IZUSVR" ]]
then
  echo "WARNING: You are running the Zowe process under user id IZUSVR. This is not recommended and may impact your z/OS MF server negatively."
fi

# reset error counter
ERRORS_FOUND=0

# Fix node.js piles up in IPC message queue
# FIXME: where is the best place for this fix? Currently it's here because global-validate.sh script is supposed to run only once.
. ${ROOT_DIR}/scripts/utils/cleanup-ipc-mq.sh

# Make sure INSTANCE_DIR is accessible and writable to the user id running this
validate_directory_is_writable "${INSTANCE_DIR}"

# Validate keystore directory accessible
validate_directory_is_accessible "${KEYSTORE_DIRECTORY}"

########################################################
# Summary errors check, exit if errors found
check_for_errors_found
