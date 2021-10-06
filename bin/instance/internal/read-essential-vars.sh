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
# This script will provide the most basic variables to move on.
# It requires INSTANCE_DIR to be set.
#
# It will provide these variables for sure:
# - ROOT_DIR
# - ZOWE_PREFIX
# - ZOWE_INSTANCE

[ -z "$(is_instance_utils_sourced 2>/dev/null || true)" ] && . ${INSTANCE_DIR}/bin/internal/utils.sh
read_essential_vars
