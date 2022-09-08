#!/bin/sh

#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

USE_CONFIGMGR=$(check_configmgr_enabled)
if [ "${USE_CONFIGMGR}" = "true" ]; then
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/internal/container/init/cli.js"
else


print_level0_message "Prepare Zowe containerization runtime environment"

#######################################################################
# Constants
PLUGINS_DIR=${ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY}/app-server/plugins
STATIC_DEF_CONFIG_DIR=${ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY}/api-mediation/api-defs

#######################################################################
print_level1_message "Before preparation"
print_message "  - whoami?" && whoami
print_message "  - ${ZWE_PRIVATE_CONTAINER_COMPONENT_RUNTIME_DIRECTORY}" && ls -la "${ZWE_PRIVATE_CONTAINER_COMPONENT_RUNTIME_DIRECTORY}"
print_message "  - /home" && ls -la "/home"
print_message "  - /home/zowe" && ls -la "/home/zowe"

#######################################################################
print_level1_message "Prepare runtime directory"
mkdir -p ${ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY}/components
cp -r ${ZWE_PRIVATE_CONTAINER_COMPONENT_RUNTIME_DIRECTORY}/. ${ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY}

#######################################################################
print_level1_message "Prepare log and workspace directories"
mkdir -p "${ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY}/tmp"
touch ${ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY}/.init-for-container

#######################################################################
print_level1_message "After preparation"
print_message "  - ${ZWE_PRIVATE_CONTAINER_COMPONENT_RUNTIME_DIRECTORY}" && ls -la "${ZWE_PRIVATE_CONTAINER_COMPONENT_RUNTIME_DIRECTORY}"
print_message "  - ${ZWE_PRIVATE_CONTAINER_HOME_DIRECTORY}" && ls -la "${ZWE_PRIVATE_CONTAINER_HOME_DIRECTORY}"
[ -d "${ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY}" ] && print_message "  - ${ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY}" && ls -la "${ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY}"
[ -d "${ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY}/components" ] && print_message "  - ${ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY}/components" && ls -la "${ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY}/components"
[ -d "${ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY}" ] && print_message "  - ${ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY}" && ls -la "${ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY}"
[ -d "${PLUGINS_DIR}" ] && print_message "  - ${PLUGINS_DIR}" && ls -la "${PLUGINS_DIR}"
[ -d "${STATIC_DEF_CONFIG_DIR}" ] && print_message "  - ${STATIC_DEF_CONFIG_DIR}" && ls -la "${STATIC_DEF_CONFIG_DIR}"

###############################
# exit message
print_level1_message "Zowe containerization runtime environment is prepared successfully."

fi
