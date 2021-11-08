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


# Takes 2 parameters - zosmfhost, zosmfport
validate_zosmf_host_and_port() {
  zosmf_host=$1
  zosmf_port=$2

  if [[ -z "${zosmf_host}" ]]
  then 
    print_error_message "The z/OSMF host was not set"
    return 1
  fi

  if [[ -z "${zosmf_port}" ]]
  then 
    print_error_message "The z/OSMF port was not set"
    return 1
  fi

  # SH: Note - if node is not available then will continue with a warning
  if [ -z "${NODE_HOME}" ];
  then
    log_message "Warning: Could not validate if z/OS MF is available on 'https://${zosmf_host}:${zosmf_port}/zosmf/info'"
  else
    http_response_code=$(${NODE_HOME}/bin/node ${utils_dir}/curl.js https://${zosmf_host}:${zosmf_port}/zosmf/info -k -H "X-CSRF-ZOSMF-HEADER: true" --response-type status)
    check_zosmf_info_response_code "${zosmf_host}" "${zosmf_port}" "${http_response_code}"
    return $?
  fi
}
