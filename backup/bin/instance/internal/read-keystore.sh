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

# Note: this file is kept for backward compatible purpose.
#       If the instance is using zowe.yaml config, the keystore environments are
#       already loaded with read-instance.sh. This is only useful if the instance
#       is using instance.env.

# Requires INSTANCE_DIR to be set
. ${INSTANCE_DIR}/bin/internal/read-essential-vars.sh

# this is only valid if we use instance.env
if [ "${ZWELS_CONFIG_LOAD_METHOD}" = "instance.env" ]; then
  if [ -z "${KEYSTORE_DIRECTORY}" -o ! -r "${KEYSTORE_DIRECTORY}/zowe-certificates.env" ]; then
    # exit immediately if file cannot be accessed
    exit_with_error "${KEYSTORE_DIRECTORY}/zowe-certificates.env does not exist"
  fi
  # Read in properties by executing, then export all the keys so we don't need to shell share
  source_env "${KEYSTORE_DIRECTORY}/zowe-certificates.env"
fi
