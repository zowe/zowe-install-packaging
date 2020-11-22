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
# - ROOT_DIR
# - <Anything else defined in instance.env and zowe-certificates.env>
################################################################################

. ${ROOT_DIR}/bin/internal/prepare-environment.sh
echo "${LAUNCH_COMPONENTS}"
