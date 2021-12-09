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

  if [ -z "${zosmf_host}" ]; then 
    print_error "z/OSMF host is not set."
    return 1
  fi

  if [ -z "${zosmf_port}" ]; then 
    print_error "z/OSMF port is not set."
    return 1
  fi

  # SH: Note - if node is not available then will continue with a warning
  if [ -z "${NODE_HOME}" ]; then
    print_error "Warning: Could not validate if z/OS MF is available on 'https://${zosmf_host}:${zosmf_port}/zosmf/info'"
  else
    http_response_code=$("${NODE_HOME}/bin/node" "${ZWE_zowe_runtimeDirectory}/bin/utils/curl.js" "https://${zosmf_host}:${zosmf_port}/zosmf/info" -k -H "X-CSRF-ZOSMF-HEADER: true" --response-type status)
    if [ -z "${http_response_code}" ]; then
      print_error "Warning: Could not validate if z/OS MF is available on 'https://${zosmf_host}:${zosmf_port}/zosmf/info'"
    elif [ ${http_response_code} != 200 ]; then
      print_error "Could not contact z/OS MF on 'https://${zosmf_host}:${zosmf_port}/zosmf/info' - ${http_response_code}"
      return 1
    fi
  fi

  print_message "Successfully checked z/OS MF is available on 'https://${zosmf_host}:${zosmf_port}/zosmf/info'"
}

validate_zosmf_as_auth_provider() {
  zosmf_host=$1
  zosmf_port=$2
  auth_provider=$3

  if [ -n "${zosmf_host}" -a -n "${zosmf_port}" ]; then
    if [ "${auth_provider}" = "zosmf" ]; then
      print_error "z/OSMF is not configured. Using z/OSMF as authentication provider is not supported."
      return 1
    fi
  fi
}
