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
# This script take these parameters
# - c:    INSTANCE_DIR
# - t:    one component ID. For backward compatible purpose, the parameter can
#         also be a directory to the component lifecycle script folder.
#
# Zowe Launcher may use this script to start a component, so there may no any
# environment variables prepared.
#
# For example:
# $ bin/internal/start-component.sh \
#        -c "/path/to/my/zowe/instance" \
#        -o "discovery"
################################################################################

# if the user passes INSTANCE_DIR from command line parameter "-c"
while getopts "c:o:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    o) component_id=${OPTARG};;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done

########################################################
# prepare environment variables
export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}"

########################################################
# find component root directory and execute start script
component_dir=$(find_component_directory "${component_id}")
# backward compatible purpose, some may expect this variable to be component lifecycle directory
export LAUNCH_COMPONENT="${component_dir}/bin"
# FIXME: change here to read manifest `commands.start` entry
start_script=${component_dir}/bin/start.sh

if [ ! -z "${component_dir}" -a -x "${start_script}" ]; then
  COMPONENT_NAME=$(cd ${component_id}/../ && echo "${PWD##*/}")
  if [ "${COMPONENT_NAME}" == "zss"]
  then
    COMPONENT_NAME="zssServer" #backwards compatibility
  elif [ "${COMPONENT_NAME}" == "app-server"]
  then
    COMPONENT_NAME="appServer" #backwards compatibility
  fi

  ZWE_LOG_FILE=${ZWE_LOG_DIR}/${COMPONENT_NAME}-${LOG_SUFFIX}
  if [ -z $ZWE_NO_LOGFILE ]
  then
    if [ ! -e "$ZWE_LOG_FILE" ]
    then
      touch $ZWE_LOG_FILE
      if [ $? -ne 0 ]
      then
        echo "Cannot make log file '$ZWE_LOG_FILE'.  Logging disabled."
        ZWE_NO_LOGFILE=1
      fi
    else
      if [ -d "$ZWE_LOG_FILE" ]
      then
        echo "ZWE_LOG_FILE '$ZWE_LOG_FILE' is a directory.  Must be a file.  Logging disabled."
        ZWE_NO_LOGFILE=1
      fi
    fi
    if [ ! -w "$ZWE_LOG_FILE" ]
    then
      echo "file '$ZWE_LOG_FILE' is not writable. Logging disabled."
      ZWE_NO_LOGFILE=1
    fi
  fi
  if [ -z "$ZWE_NO_LOGFILE" ]
  then
    #Clean up excess logs, if appropriate.
    if [ $ZWE_ROTATE_LOGS -ne 0 ]
    then
      for f in `ls -r -1 $ZWE_LOG_DIR/${component_id}-*.log 2>/dev/null | tail +$ZWE_LOGS_TO_KEEP`
      do
        echo "${component_id} removing old log file '$f'"
        rm -f $f
      done
    fi
    echo "${component_id} log file=${ZWE_LOG_FILE}"
    . ${start_script} 2>&1 | tee ${ZWE_LOG_FILE} | grep -E "(INFO|WARN|CRITICAL|ERROR)"
  else
    echo "${component_id} not logging to a file"
    . ${start_script}
  fi
fi
