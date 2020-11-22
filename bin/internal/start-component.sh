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
# This script will start a Zowe component.
#
# This script take one parameter as component ID. For backward compatible purpose,
# the parameter can also be a directory to the component lifecycle script folder.
#
# Zowe Launcher may use this script to start a component, so there may no any
# environment variables prepared.
#
# For example:
# $ bin/internal/start-component.sh "discovery"
################################################################################

LAUNCH_COMPONENT=$0

export ROOT_DIR=$(cd $(dirname $0)/../../;pwd) #we are in <ROOT_DIR>/bin/internal/run-zowe.sh
# reload environment if not loaded
. ${ROOT_DIR}/bin/internal/prepare-environment.sh

# find component lifecycle scripts directory
component_lifecycle_dir=
if [ -d "${LAUNCH_COMPONENT}" ]; then
  component_lifecycle_dir=$LAUNCH_COMPONENT
else
  if [ -d "${ROOT_DIR}/components/${LAUNCH_COMPONENT}" ]; then
    # this is a Zowe build-in component
    if [ -d "${ROOT_DIR}/components/${LAUNCH_COMPONENT}/bin" ]; then
      component_lifecycle_dir="${ROOT_DIR}/components/${LAUNCH_COMPONENT}/bin"
    fi
  elif [ ! -z "${ZWE_EXTENSION_DIR}" ]; then
    if [ -d "${ZWE_EXTENSION_DIR}/${LAUNCH_COMPONENT}" ]; then
      # this is an extension installed/linked in ZWE_EXTENSION_DIR
      if [ -d "${ZWE_EXTENSION_DIR}/${LAUNCH_COMPONENT}/bin" ]; then
        component_lifecycle_dir="${ZWE_EXTENSION_DIR}/${LAUNCH_COMPONENT}/bin"
      fi
    fi
  fi
fi

if [ ! -z "${component_lifecycle_dir}" -a -f "${component_lifecycle_dir}/start.sh" ]; then
  . ${LAUNCH_COMPONENT}/start.sh
fi
