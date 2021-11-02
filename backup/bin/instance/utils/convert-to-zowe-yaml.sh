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
# This utility script will convert instance.env to zowe.yaml format.
#
# parameter(s):
# - optional, path to instance.env
# - optional, path to zowe.yaml to generate
#
# If there is only one parameter, it will be treated as path to zowe.yaml.
################################################################################

INSTANCE_DIR=$(cd $(dirname $0)/../../;pwd)
INSTANCE_ENV=
TARGET_YAML=
if [ "$#" -eq 2 ]; then
  INSTANCE_ENV=$1
  TARGET_YAML=$2
elif [ "$#" -eq 1 ]; then
  TARGET_YAML=$1
fi
if [ -z "${INSTANCE_ENV}" ]; then
  INSTANCE_ENV="${INSTANCE_DIR}/instance.env"
fi

# zowe
if [ ! -f "${INSTANCE_ENV}" ]; then
  >&2 echo "Error: cannot find file ${INSTANCE_ENV}"
  exit 1
fi

# source utility scripts
[ -z "$(is_instance_utils_sourced 2>/dev/null || true)" ] && . ${INSTANCE_DIR}/bin/internal/utils.sh
read_essential_vars
[ -z "$(is_runtime_utils_sourced 2>/dev/null || true)" ] && . ${ROOT_DIR}/bin/utils/utils.sh

# import common environment variables to make sure node runs properly
. "${ROOT_DIR}/bin/internal/zowe-set-env.sh"

# generate zowe.yaml.sample
# we need node for following commands
ensure_node_is_on_path 1>/dev/null 2>&1
convert_instance_env_to_yaml "${INSTANCE_ENV}" "${TARGET_YAML}"
