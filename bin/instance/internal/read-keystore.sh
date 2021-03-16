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

# Requires INSTANCE_DIR, KEYSTORE_DIRECTORY to be set
if [ -z "$(LC_ALL=C type read_essential_vars | grep 'function')" ]; then
  . ${INSTANCE_DIR}/bin/internal/utils.sh
fi
if [ -z "${ROOT_DIR}" ]; then
  read_essential_vars
fi

if [ -z "${KEYSTORE_DIRECTORY}" ]; then
  # we don't have this var, this may happen with zowe.yaml
  # which will source the certificate variables from instance-<ha-id>.env
  exit 0
fi
if [ ! -r "${KEYSTORE_DIRECTORY}/zowe-certificates.env" ]; then
  # exit immediately if file cannot be accessed
  exit 1
fi
# Read in properties by executing, then export all the keys so we don't need to shell share
source_env "${KEYSTORE_DIRECTORY}/zowe-certificates.env"
