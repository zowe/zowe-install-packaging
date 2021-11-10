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

export ZOWE_LOG_FILE=

prepare_log_file() {
  log_dir=$1
  log_file_prefix=$2

  export ZOWE_LOG_FILE="${log_dir}/${log_file_prefix}-$(date +%Y%m%dT%H%M%S).log"
  if [ ! -f "${ZOWE_LOG_FILE}" ]; then
    # create and echo message if log file doesn't exist
    touch ${ZOWE_LOG_FILE}
    echo "Log file created: ${ZOWE_LOG_FILE}"
  fi
  chmod a+rw ${ZOWE_LOG_FILE}
}
