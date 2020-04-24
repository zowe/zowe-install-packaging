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

set_log_file_from_full_path() {
  export LOG_FILE=$1
  touch ${LOG_FILE}
  chmod a+rw ${LOG_FILE}
  echo "Log file created: ${LOG_FILE}"
}

set_log_file() {
  LOG_FILE_PREFIX=$1
  set_log_file_from_full_path "${LOG_DIRECTORY}/${LOG_FILE_PREFIX}-`date +%Y-%m-%d-%H-%M-%S`.log"
}

set_log_directory() {
  LOG_DIRECTORY=$1

  # If log directory not specified on input try /global/zowe/logs then ~/zowe/logs
  if [[ -z "${LOG_DIRECTORY}" ]]
  then
    if [[ -w "/global/zowe" ]]
    then 
      LOG_DIRECTORY="/global/zowe/logs"
    else
      LOG_DIRECTORY="~/zowe/logs"
    fi
  else
    # If the path is relative, then expand it
    if [[ "$LOG_DIRECTORY" != /* ]]
    then
      LOG_DIRECTORY=$PWD/$LOG_DIRECTORY
    fi
  fi

  # If the value starts with a ~ for the home variable then evaluate it
  LOG_DIRECTORY=`sh -c "echo $LOG_DIRECTORY"`

  if ! mkdir -p ${LOG_DIRECTORY}
  then
    echo "Unable to create directory ${LOG_DIRECTORY}. Please use call the script with the additional parameter '-l <log_dir>' specifying a creatable and writable log_dir"
    exit 1
  elif [[ ! -w ${LOG_DIRECTORY} ]]
  then	
    echo "The directory ${LOG_DIRECTORY} was not writable. Please use call the script with the additional parameter '-l <log_dir>' specifying a writable log_dir"
    exit 1
  fi

  export LOG_DIRECTORY
}