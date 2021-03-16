#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

################################################################################
# This script will start Zowe.
################################################################################

OPTIND=1
while getopts "c:i:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    i) HA_INSTANCE_ID=${OPTARG};;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done

# export this to other scripts
export INSTANCE_DIR
# find runtime directory to locate the scripts
# this value should be trustworthy since this script is not supposed to be sourced
export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)

# source utility scripts
[ -z "$(is_instance_utils_sourced 2>/dev/null || true)" ] && . ${INSTANCE_DIR}/bin/internal/utils.sh
[ -z "$(is_runtime_utils_sourced 2>/dev/null || true)" ] && . ${ROOT_DIR}/bin/utils/utils.sh
reset_env_dir

# assign default value
if [ -z "${HA_INSTANCE_ID}" ]; then
  HA_INSTANCE_ID=$(get_sysname)
fi

# display starting information
print_formatted_info "ZWELS" "run-zowe.sh:${LINENO}" "starting Zowe instance ${HA_INSTANCE_ID} from ${INSTANCE_DIR} ..."
print_formatted_debug "ZWELS" "run-zowe.sh:${LINENO}" "use configuration defined in ${ZWE_CONFIG_LOAD_METHOD}"
# generic prepare environment
. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -i "${HA_INSTANCE_ID}"
# global validations
. ${ROOT_DIR}/bin/internal/global-validate.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -i "${HA_INSTANCE_ID}"
# find what components should be started
launch_components_list=$(${ROOT_DIR}/bin/internal/get-launch-components.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -i "${HA_INSTANCE_ID}")
if [ -z "${launch_components_list}" ]; then
  print_formatted_error "ZWELS" "run-zowe.sh:${LINENO}" "no components are enabled for this instance"
  exit 1
fi
# prepare workspace
. ${ROOT_DIR}/bin/internal/prepare-workspace.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -i "${HA_INSTANCE_ID}" -t "${launch_components_list}"
# display 
print_formatted_info "ZWELS" "run-zowe.sh:${LINENO}" "Zowe runtime environment prepared"

# display starting information
print_formatted_debug "ZWELS" "run-zowe.sh:${LINENO}" "starting component(s) ${launch_components_list} ..."
# FIXME: Zowe Launcher can take responsibility from here
for component_id in $(echo "${launch_components_list}" | sed "s/,/ /g"); do
  ${ROOT_DIR}/bin/internal/start-component.sh -c "${INSTANCE_DIR}" -r "${ROOT_DIR}" -i "${HA_INSTANCE_ID}" -o "${component_id}" &
done
