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

# Try and source the file utils if it exists
if [[ -f "${ZOWE_ROOT_DIR}/bin/utils/file-utils.sh" ]]
then
. ${ZOWE_ROOT_DIR}/bin/utils/file-utils.sh
fi

set_install_log_file_from_full_path() {
  export LOG_FILE=$1
  touch ${LOG_FILE}
  chmod a+rw ${LOG_FILE}
  echo "Log file created: ${LOG_FILE}"
}

set_install_log_file() {
  LOG_FILE_PREFIX=$1
  set_install_log_file_from_full_path "${LOG_DIRECTORY}/${LOG_FILE_PREFIX}-`date +%Y-%m-%d-%H-%M-%S`.log"
}

get_install_log_directory() {
  INSTALL_LOG_DIR=$1
  
  # If log directory not specified on input try /global/zowe/logs then ~/zowe/logs
  if [[ -z "${INSTALL_LOG_DIR}" ]]
  then
    if [[ -r "/global/zowe" ]]
    then 
      INSTALL_LOG_DIR="/global/zowe/logs"
    else
      INSTALL_LOG_DIR="~/zowe/logs"
    fi
  fi

  INSTALL_LOG_DIR=$(get_full_path "${INSTALL_LOG_DIR}")

  if { [[ ! -d "${INSTALL_LOG_DIR}" ]] || [[ ! -r "${INSTALL_LOG_DIR}" ]] }
  then	
    echo "The directory ${INSTALL_LOG_DIR} was not readable. Please use call the script with the additional parameter '-l <log_dir>' specifying the directory that the install and setup log(s) were created in"
    exit 1
  fi
  export INSTALL_LOG_DIR
}

set_install_log_directory() {
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
  fi
  LOG_DIRECTORY=$(get_full_path "${LOG_DIRECTORY}")

  if ! mkdir -p ${LOG_DIRECTORY}
  then
    echo "Unable to create directory ${LOG_DIRECTORY}. Please use call the script with the additional parameter '-l <log_dir>' specifying a creatable and writable log_dir"
    exit 1
  elif [[ ! -w "${LOG_DIRECTORY}" ]]
  then	
    echo "The directory ${LOG_DIRECTORY} was not writable. Please use call the script with the additional parameter '-l <log_dir>' specifying a writable log_dir"
    exit 1
  fi

  export LOG_DIRECTORY
}

validate_log_file_not_in_root_dir() {
  LOG_DIR=$1
  ROOT_DIR=$2
  validate_file_not_in_directory "${LOG_DIR}" "${ROOT_DIR}"
  if [[ $? -ne 0 ]]
  then
    echo "It looks like the log directory chosen ${LOG_DIR} was within the zowe runtime install directory ${ROOT_DIR}. The install directory is designed to be read only. Please re-run with the additional parameter '-l <log_dir>' specifying a writable log_dir outside of the install directory"
    exit 1
  fi
}