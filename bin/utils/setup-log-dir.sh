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