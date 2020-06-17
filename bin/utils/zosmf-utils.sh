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

# TODO LATER - anyway to do this better?
# Try and work out where we are even if sourced
if [[ -n ${INSTALL_DIR} ]]
then
  export utils_dir="${INSTALL_DIR}/bin/utils"
elif [[ -n ${ZOWE_ROOT_DIR} ]]
then
  export utils_dir="${ZOWE_ROOT_DIR}/bin/utils"
elif [[ -n ${ROOT_DIR} ]]
then
  export utils_dir="${ROOT_DIR}/bin/utils"
elif [[ $0 == "zosmf-utils.sh" ]] #Not called by source
then
  export utils_dir=$(cd $(dirname $0);pwd)
else
  echo "Could not work out the path to the utils directory. Please 'export ZOWE_ROOT_DIR=<zowe-root-directory>' before running." 1>&2
  return 1
fi

# Source common util functions
. ${utils_dir}/common.sh

prompt_zosmf_port_if_required() {
  zosmf_port_list=$(onetstat -b -E IZUSVR1 2>/dev/null | grep .*Listen | awk '{ print $4 }')
  extract_zosmf_port "${zosmf_port_list}"
  extract_rc=$?
  if [[ ${extract_rc} -ne 0 ]]
  then
    echo "Unable to detect z/OS MF HTTPS port"
    echo "Please enter the HTTPS port of z/OS MF server on this system"
    read zosmf_port_list
    export ZOWE_ZOSMF_PORT=${zosmf_port_list}
  fi
}

extract_zosmf_port() {
  zosmf_port_list=$1
  if [[ -z "${zosmf_port_list}" ]]
  then
    number_of_matches=0
  else
    number_of_matches=$(echo "${zosmf_port_list}" | wc -l)
  fi
  
  # TODO - tidy up later - we currently have 2 different names for the zosmf variables during and after install
  if [[ -n "${ZOSMF_HOST}" ]]
  then
     ZOSMF_HOST=${ZOWE_ZOSMF_HOST}
  fi

  # Zip 1124 - in z/OS 2.4 some people have reported 2 ports for z/OS MF. If we know host name at this point, try to work out which is correct
  if [[ ${number_of_matches} -gt 1 ]] && [[ -n "${ZOSMF_HOST}" ]] && [[ -n "${NODE_HOME}" ]];
  then
    for port in ${zosmf_port_list}; do
      http_response_code=$(${NODE_HOME}/bin/node ${utils_dir}/zosmfHttpRequest.js ${ZOSMF_HOST} ${port})
      if [[ ${http_response_code} == 200 ]]
      then
        zosmf_port_list=${port}
        number_of_matches=1
        break
      fi
    done
  fi

  if [[ ${number_of_matches} -ne 1 ]]
  then
    return 1
  fi
  export ZOWE_ZOSMF_PORT=${zosmf_port_list}
}

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
    http_response_code=$(${NODE_HOME}/bin/node ${utils_dir}/zosmfHttpRequest.js ${zosmf_host} ${zosmf_port})
    check_zosmf_info_response_code "${http_response_code}"
    return $?
  fi
}

check_zosmf_info_response_code() {
  http_response_code=$1
  if [[ -z "${http_response_code}" ]]
  then
    log_message "Warning: Could not validate if z/OS MF is available on 'https://${ZOSMF_HOST}:${ZOSMF_PORT}/zosmf/info'"
  else
    if [[ ${http_response_code} != 200 ]]
    then
      print_error_message "Could not contact z/OS MF on 'https://${ZOSMF_HOST}:${ZOSMF_PORT}/zosmf/info' - ${http_response_code}"
      return 1
    else
      log_message "Successfully checked z/OS MF is available on 'https://${ZOSMF_HOST}:${ZOSMF_PORT}/zosmf/info'"
    fi
  fi
}
