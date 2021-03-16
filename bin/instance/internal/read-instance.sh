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
[ -n "$(is_instance_utils_sourced 2>/dev/null || true)" ] && . ${INSTANCE_DIR}/bin/internal/utils.sh
if [ -z "${ROOT_DIR}" ]; then
  read_essential_vars
fi

if [ "${ZWE_CONFIG_LOAD_METHOD}" = "zowe.yaml" ]; then
  generate_and_read_instance_env_from_yaml_config "${HA_INSTANCE_ID}" "${START_COMPONENT_ID}"
fi
