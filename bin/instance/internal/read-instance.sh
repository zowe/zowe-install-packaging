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

# Requires INSTANCE_DIR to be set
if [ -z "$(LC_ALL=C type read_essential_vars | grep -q 'shell function')" ]; then
  . ${INSTANCE_DIR}/bin/internal/utils.sh
fi
if [ -z "${ROOT_DIR}" ]; then
  read_essential_vars
fi

if [ ! -f "${INSTANCE_DIR}/instance.env" -a -f "${INSTANCE_DIR}/zowe.yaml" ]; then
  prepare_and_read_instance_env "${HA_INSTANCE_ID}" "${START_COMPONENT_ID}"
fi
