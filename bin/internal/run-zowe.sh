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

# LAUNCH_COMPONENTS can also get from stdout of bin/internal/get-launch-components.sh
for component_id in $(echo "${LAUNCH_COMPONENTS}" | sed "s/,/ /g"); do
  ${ROOT_DIR}/bin/internal/start-component.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -i "${ZWELS_HA_INSTANCE_ID}" -o "${component_id}"
done
