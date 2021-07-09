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

export INSTANCE_DIR=$(cd $(dirname $0)/../../;pwd)
. ${INSTANCE_DIR}/bin/internal/read-essential-vars.sh
. ${ROOT_DIR}/bin/zowe-install-component.sh "$@"
