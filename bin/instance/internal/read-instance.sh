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
[ -z "$(is_instance_utils_sourced 2>/dev/null || true)" ] && . ${INSTANCE_DIR}/bin/internal/utils.sh
if [ -z "${ROOT_DIR}" ]; then
  read_essential_vars
fi

if [ "${ZWELS_CONFIG_LOAD_METHOD}" = "zowe.yaml" ]; then
  OPTIND=1
  while getopts "i:o:" opt; do
    case ${opt} in
      i) ZWELS_HA_INSTANCE_ID=${OPTARG};;
      o) ZWELS_START_COMPONENT_ID=${OPTARG};;
      \?)
        echo "Invalid option: -${OPTARG}" >&2
        exit 1
        ;;
    esac
  done
  shift $(($OPTIND-1))

  generate_and_read_instance_env_from_yaml_config "${ZWELS_HA_INSTANCE_ID}" "${ZWELS_START_COMPONENT_ID}"
fi
