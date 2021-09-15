#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020, 2021
################################################################################

################################################################################
# This script will start one Zowe component.
#
# This script take these parameters
# - c:    instance directory
# - o:    one component ID. For backward compatible purpose, the parameter can
#         also be a directory to the component lifecycle script folder.
# - r:    optional, root directory
# - i:    optional, HA instance ID. Default value is &SYSNAME.
# - b:    optional boolean, run component start script in background
#
# Note:
# 1. This script requires instance directory prepared for runtime. So
#    bin/internal/prepare-instance.sh should have been executed.
# 2. This script doesn't rely on any environment variables, it will load
#    everything needed.
#
# For example:
# $ bin/internal/start-component.sh \
#        -c "/path/to/my/zowe/instance" \
#        -o "discovery"
################################################################################

# if the user passes INSTANCE_DIR from command line parameter "-c"
OPTIND=1
while getopts "c:r:i:o:b" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    r) ROOT_DIR=${OPTARG};;
    i) ZWELS_HA_INSTANCE_ID=${OPTARG};;
    o) ZWELS_START_COMPONENT_ID=${OPTARG};;
    b) RUN_IN_BACKGROUND=true;;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

########################################################
# prepare environment variables
if [ -z "${ROOT_DIR}" ]; then
  # if this script is sourced, this may not return correct path
  export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
  # validate if this is zowe root path
  if [ ! -f "${ROOT_DIR}/manifest.json" ]; then
    echo "ROOT_DIR is not defined. You can either pass the value with -r parameter or define it as global environment variable." >&2
    exit 1
  fi
fi
. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -i "${ZWELS_HA_INSTANCE_ID}" -o "${ZWELS_START_COMPONENT_ID}"

########################################################
# when running in containers, kubernetes will send SIGTERM to PID 1
# gracefully shutdown all child processes by sending SIGTERM to them all
if [ -f "${INSTANCE_DIR}/.init-for-container" ]; then
  trap gracefully_shutdown 15
fi

########################################################
# find component root directory and execute start script
component_dir=$(find_component_directory "${ZWELS_START_COMPONENT_ID}")
# backward compatible purpose, some may expect this variable to be component lifecycle directory
export LAUNCH_COMPONENT="${component_dir}/bin"
start_script=$(read_component_manifest "${component_dir}" ".commands.start" 2>/dev/null)
if [ -z "${start_script}" -o "${start_script}" = "null" ]; then
  # backward compatible purpose
  if [ $(is_core_component "${component_dir}") != "true" ]; then
    print_formatted_warn "ZWELS" "start-component.sh:${LINENO}" "unable to determine start script from component ${ZWELS_START_COMPONENT_ID} manifest, fall back to default bin/start.sh"
  fi
  start_script=${component_dir}/bin/start.sh
fi
if [ -n "${component_dir}" ]; then
  cd "${component_dir}"

  # source environment snapshot created by configure step
  component_name=$(basename "${component_dir}")
  if [ -f "${ZWELS_INSTANCE_ENV_DIR}/${component_name}/.${ZWELS_HA_INSTANCE_ID}.env" ]; then
    print_formatted_debug "ZWELS" "start-component.sh:${LINENO}" "restoring environment snapshot ${ZWELS_INSTANCE_ENV_DIR}/${component_name}/.${ZWELS_HA_INSTANCE_ID}.env ..."
    # some variables we don't want to be overwritten
    ZWELS_OLD_START_COMPONENT_ID=${ZWELS_START_COMPONENT_ID}
    # restore environment snapshot created in configure step
    . "${ZWELS_INSTANCE_ENV_DIR}/${component_name}/.${ZWELS_HA_INSTANCE_ID}.env"
    # restore some backups
    ZWELS_START_COMPONENT_ID=${ZWELS_OLD_START_COMPONENT_ID}
  fi

  if [ -x "${start_script}" ]; then
    print_formatted_info "ZWELS" "start-component.sh:${LINENO}" "starting component ${ZWELS_START_COMPONENT_ID} ..."
    print_formatted_debug "ZWELS" "start-component.sh:${LINENO}" "environment for ${ZWELS_START_COMPONENT_ID}: $(get_environments | sort | tr '\n' '~')"
    # FIXME: we have assumption here start_script is pointing to a shell script
    # if [[ "${start_script}" == *.sh ]]; then
    if [ "${RUN_IN_BACKGROUND}" = "true" ]; then
      . "${start_script}" &
    else
      # wait for all background subprocesses created by bin/start.sh exit
      cat "${start_script}" | { cat ; echo; echo wait; } | /bin/sh
    fi
  fi
fi
