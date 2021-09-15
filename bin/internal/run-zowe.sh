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
# This script will start Zowe.
#
# It takes 2 parameters:
# - c:   path to instance directory
# - i:   optional, Zowe HA instance ID
################################################################################

# prepare instance/.env and instance/workspace directories
. ${ROOT_DIR}/bin/internal/prepare-instance.sh

########################################################
# when running in containers, kubernetes will send SIGTERM to PID 1
# gracefully shutdown all child processes by sending SIGTERM to them all
if [ -f "${INSTANCE_DIR}/.init-for-container" ]; then
  print_formatted_debug "ZWELS" "run-zowe.sh:${LINENO}" "trap SIGTERM signal handler registered"
  trap gracefully_shutdown 15
fi

# LAUNCH_COMPONENTS can also get from stdout of bin/internal/get-launch-components.sh
for run_zowe_start_component_id in $(echo "${LAUNCH_COMPONENTS}" | sed "s/,/ /g"); do
  if [ -n "${ZOWE_CONTAINER_COMPONENT_ID}" ]; then
    ${ROOT_DIR}/bin/internal/start-component.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -i "${ZWELS_HA_INSTANCE_ID}" -o "${run_zowe_start_component_id}"
  else
    # only run in background when it's not in container, on z/OS
    ${ROOT_DIR}/bin/internal/start-component.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -i "${ZWELS_HA_INSTANCE_ID}" -o "${run_zowe_start_component_id}" -b &
  fi
done
