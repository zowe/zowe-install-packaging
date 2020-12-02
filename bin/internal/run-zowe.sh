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

while getopts "c:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done

# export this to other scripts
export INSTANCE_DIR
# find runtime directory to locate the scripts
export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)

. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}"
. ${ROOT_DIR}/bin/internal/global-validate.sh -c "${INSTANCE_DIR}"

launch_components_list=$(${ROOT_DIR}/bin/internal/get-launch-components.sh -c "${INSTANCE_DIR}")
. ${ROOT_DIR}/bin/internal/prepare-workspace.sh -c "${INSTANCE_DIR}" -t "${launch_components_list}"

# FIXME: Zowe Launcher should probably do this file logging logic instead
# Handle log file syntax setup here so that the timestamps for all components match
# Determine if components should log to a file, and where
if [ -z "$ZWE_NO_LOGFILE" ]
then
  if [ -z "$ZWE_LOG_DIR" ]
  then
    export ZWE_LOG_DIR=${INSTANCE_DIR}/logs
  fi
  if [ -f "$ZWE_LOG_DIR" ]
  then
    export ZWE_NO_LOGFILE=1
  elif [ ! -d "$ZWE_LOG_DIR" ]
  then
    echo "Will make log directory $ZWE_LOG_DIR"
    mkdir -p $ZWE_LOG_DIR
    if [ $? -ne 0 ]
    then
      echo "Cannot make log directory.  Logging disabled."
      export ZWE_NO_LOGFILE=1
    fi
  fi
  export ZWE_ROTATE_LOGS=0
  if [ -d "$ZWE_LOG_DIR" ]
  then
    LOG_SUFFIX="`date +%Y-%m-%d-%H-%M`.log"
    if [ -z "$ZWE_LOGS_TO_KEEP" ]
    then
      export ZWE_LOGS_TO_KEEP=5
    fi
    echo $ZWE_LOGS_TO_KEEP|egrep '^\-?[0-9]+$' >/dev/null
    if [ $? -ne 0 ]
    then
      echo "ZWE_LOGS_TO_KEEP not a number.  Defaulting to 5."
      export ZWE_LOGS_TO_KEEP=5
    fi
    if [ $ZWE_LOGS_TO_KEEP -ge 0 ]
    then
      export ZWE_ROTATE_LOGS=1
    fi
  fi
fi



# FIXME: Zowe Launcher can take responsibility from here
for component_id in $(echo "${launch_components_list}" | sed "s/,/ /g"); do
  . ${ROOT_DIR}/bin/internal/start-component.sh -c "${INSTANCE_DIR}" -o "${component_id}" &
done
