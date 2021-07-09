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
. ${INSTANCE_DIR}/bin/internal/read-essential-vars.sh

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

  print_formatted_function_available=$(function_exists print_formatted_info)

  # ignore default value passed from ZWESLSTC
  if [ "${ZWELS_HA_INSTANCE_ID}" = "{{ha_instance_id}}" -o "${ZWELS_HA_INSTANCE_ID}" = "__ha_instance_id__" ]; then
    ZWELS_HA_INSTANCE_ID=
  fi
  # If HA instance ID doesn't exist, it will raise an error.
  if [ -z "${ZWELS_HA_INSTANCE_ID}" ]; then
    exit_with_error "-i <ZWELS_HA_INSTANCE_ID> is required" "read-instance.sh:${LINENO}"
  fi
  # sanitize instance id
  ZWELS_HA_INSTANCE_ID=$(echo "${ZWELS_HA_INSTANCE_ID}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/_/g')

  # Source appropriate instance.env variables based on HA instance ID and component.
  if [ "${ZWELS_START_COMPONENT_ID}" != "" -a -f "${ZWELS_INSTANCE_ENV_DIR}/${ZWELS_START_COMPONENT_ID}/.instance-${ZWELS_HA_INSTANCE_ID}.env" ]; then
    message="loading ${ZWELS_INSTANCE_ENV_DIR}/${ZWELS_START_COMPONENT_ID}/.instance-${ZWELS_HA_INSTANCE_ID}.env"
    if [ "${print_formatted_function_available}" = "true" ]; then
      print_formatted_debug "ZWELS" "read-instance.sh:${LINENO}" "${message}"
    fi
    source_env "${ZWELS_INSTANCE_ENV_DIR}/${ZWELS_START_COMPONENT_ID}/.instance-${ZWELS_HA_INSTANCE_ID}.env"
  elif [ -f "${ZWELS_INSTANCE_ENV_DIR}/.instance-${ZWELS_HA_INSTANCE_ID}.env" ]; then
    message="loading ${ZWELS_INSTANCE_ENV_DIR}/.instance-${ZWELS_HA_INSTANCE_ID}.env"
    if [ "${print_formatted_function_available}" = "true" ]; then
      print_formatted_debug "ZWELS" "read-instance.sh:${LINENO}" "${message}"
    fi
    source_env "${ZWELS_INSTANCE_ENV_DIR}/.instance-${ZWELS_HA_INSTANCE_ID}.env"
  else
    # something wrong, could be conversion wasn't successful
    if [ "${ZWELS_START_COMPONENT_ID}" != "" ]; then
      message="compatible version of <instance>/.env/${ZWELS_START_COMPONENT_ID}/.instance-${ZWELS_HA_INSTANCE_ID}.env doe snot exist"
    else
      message="compatible version of <instance>/.env/.instance-${ZWELS_HA_INSTANCE_ID}.env does not exist"
    fi
    exit_with_error "${message}" "read-instance.sh:${LINENO}"
  fi
fi
