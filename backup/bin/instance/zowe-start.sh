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

set -e
export ZWELS_HA_INSTANCE_ID=$1
export INSTANCE_DIR=$(cd $(dirname $0)/../;pwd)
. ${INSTANCE_DIR}/bin/internal/read-essential-vars.sh

# FIXME: prepare for HA deployment
# ${ROOT_DIR}/scripts/internal/opercmd "S ZWESVSTC,INSTANCE='"${INSTANCE_DIR}"',HA='"${ZWELS_HA_INSTANCE_ID}"',JOBNAME=${ZOWE_PREFIX}${ZOWE_INSTANCE}SV"
${ROOT_DIR}/scripts/internal/opercmd "S ZWESVSTC,INSTANCE='"${INSTANCE_DIR}"',JOBNAME=${ZOWE_PREFIX}${ZOWE_INSTANCE}SV"
echo Start command issued, check SDSF job log ...
