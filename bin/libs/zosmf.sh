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
  zosmf_host="${1}"
  zosmf_port="${2}"

  if [ -z "${zosmf_host}" ]; then 
    print_error "z/OSMF host is not set."
    return 1
  fi

  if [ -z "${zosmf_port}" ]; then 
    print_error "z/OSMF port is not set."
    return 1
  fi

  zosmf_check_passed=true

  http_response_code=$("${ZWE_zowe_runtimeDirectory}/bin/utils/curl" "https://${zosmf_host}:${zosmf_port}/zosmf/info" -k -H "X-CSRF-ZOSMF-HEADER: true" -w "%{http_code}" -s -o /dev/null)
  if [ -z "${http_response_code}" ]; then
    print_error "Warning: Could not validate if z/OSMF is available on 'https://${zosmf_host}:${zosmf_port}/zosmf/info'. No response code from z/OSMF server."
    zosmf_check_passed=false
  # RSU2512 -> running z/OSMF is returning 401
  elif [ ${http_response_code} != 200 -a ${http_response_code} != 401 ]; then
    print_error "Could not contact z/OSMF on 'https://${zosmf_host}:${zosmf_port}/zosmf/info' - ${http_response_code}"
    zosmf_check_passed=false
    return 1
  fi
  

  if [ "${zosmf_check_passed}" = "true" ]; then
    print_message "Successfully checked z/OSMF is available on 'https://${zosmf_host}:${zosmf_port}/zosmf/info'"
  fi
}
