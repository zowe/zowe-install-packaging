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

export ZWELS_HA_INSTANCE_ID=$1
export INSTANCE_DIR=$(cd $(dirname $0)/../../;pwd)
if [[ ! -z "${EXTERNAL_INSTANCE}" ]]
then
  INTERNAL_INSTANCE=/var/zowe/instance
  INSTANCE_DIR=$EXTERNAL_INSTANCE
fi

. ${INSTANCE_DIR}/bin/internal/utils.sh
read_essential_vars
${ROOT_DIR}/bin/internal/run-zowe.sh -c "${INSTANCE_DIR}" -i "${ZWELS_HA_INSTANCE_ID}"
