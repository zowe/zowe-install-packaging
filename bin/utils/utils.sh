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

# This is a single library that sources the other utils to make them easier for extenders to call

# TODO LATER - anyway to do this better?
# Try and work out where we are even if sourced
if [[ -n ${INSTALL_DIR} ]]
then
  export utils_dir="${INSTALL_DIR}/bin/utils"
elif [[ -n ${ZOWE_ROOT_DIR} ]]
then
  export utils_dir="${ZOWE_ROOT_DIR}/bin/utils"
elif [[ -n ${ROOT_DIR} ]]
then
  export utils_dir="${ROOT_DIR}/bin/utils"
elif [[ $0 == "zosmf-utils.sh" ]] #Not called by source
then
  export utils_dir=$(cd $(dirname $0);pwd)
else
  echo "Could not work out the path to the utils directory. Please 'export ZOWE_ROOT_DIR=<zowe-root-directory>' before running." 1>&2
  return 1
fi

# Source all util functions
. ${utils_dir}/common.sh
. ${utils_dir}/file-utils.sh
. ${utils_dir}/java-utils.sh
. ${utils_dir}/network-utils.sh
. ${utils_dir}/node-utils.sh
. ${utils_dir}/setup-log-dir.sh
. ${utils_dir}/zosmf-utils.sh
. ${utils_dir}/zowe-variable-utils.sh
. ${utils_dir}/component-utils.sh
