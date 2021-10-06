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
elif [[ $0 == "zowe-variable-utils.sh" ]] #Not called by source
then
  export utils_dir=$(cd $(dirname $0);pwd)
else
  echo "Could not work out the path to the utils directory. Please 'export ZOWE_ROOT_DIR=<zowe-root-directory>' before running." 1>&2
  return 1
fi

# Source common util functions
. ${utils_dir}/common.sh

# Takes in a single parameter - the name of the variable
validate_variable_is_set() {
  variable_name=$1
  eval "value=\"\$${variable_name}\""
  if [[ -z "${value}" ]]
  then
    print_error_message "${variable_name} is empty"
    return 1
  fi
}

# Takes in a list of space separated names of the variables
validate_variables_are_set() {
  invalid=0
  for var in $(echo $1 | sed "s/,/ /g")
  do
    validate_variable_is_set "${var}"
    valid_rc=$?
    if [[ ${valid_rc} -ne 0 ]]
    then	
      let "invalid=${invalid}+1"
    fi
  done
  return $invalid
}

###############################
# Check if a shell function is defined
#
# @param string   function name
# Output          true if the function is defined
function_exists() {
  fn=$1
  status=$(LC_ALL=C type $fn 2>&1 | grep 'function')
  if [ -n "${status}" ]; then
    echo "true"
  fi
}

###############################
# if a string has any env variables, replace them with values
parse_string_vars() {
  eval echo "${1}"
}

###############################
# get all environment variable exports line by line
get_environment_exports() {
  export -p | \
    grep -v -E '^export (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD=|PS1=|ENV=|LS_COLORS=|_=)' | \
    grep -v -E '^declare -x (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD|PS1=|ENV=|LS_COLORS=|_=)'
}

###############################
# get all environment variable exports line by line
get_environments() {
  export -p | \
    grep -v -E '^export (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD=|PS1=|ENV=|LS_COLORS=|_=)' | \
    grep -v -E '^declare -x (run_zowe_start_component_id=|ZWELS_START_COMPONENT_ID|ZWE_LAUNCH_COMPONENTS|env_file=|key=|line=|service=|logger=|level=|expected_log_level_val=|expected_log_level_var=|display_log=|message=|utils_dir=|print_formatted_function_available=|LINENO=|ENV|opt|OPTARG|OPTIND|LOGNAME=|USER=|SSH_|SHELL=|PWD=|OLDPWD|PS1=|ENV=|LS_COLORS=|_=)' | \
    sed -e 's#^export ##' | \
    sed -e 's#^declare -x ##'
}

# ZOWE_PREFIX + instance - should be <=6 char long and exist.
# TODO - any lower bound (other than 0)?
# Requires ZOWE_PREFIX to be set as a shell variable
validate_zowe_prefix() {
  validate_variable_is_set "ZOWE_PREFIX"
  prefix_set_rc=$?
  if [[ ${prefix_set_rc} -eq 0 ]]
  then
    PREFIX_LENGTH=${#ZOWE_PREFIX}
    if [[ $PREFIX_LENGTH > 6 ]]
    then
      print_error_message "ZOWE_PREFIX '${ZOWE_PREFIX}' should be less than 7 characters"
      return 1
    fi
  else
    return $prefix_set_rc
  fi
}

# return value of a variable defined in zowe instance env
read_zowe_instance_variable() {
  variable_name=$1

  # source in a new shell so it shouldn't mess the current shell
  echo $(echo ". ${INSTANCE_DIR}/instance.env && echo \$${variable_name}" | sh)
}

# read yaml key value
read_zowe_yaml_variable() {
  key=$1

  utils_dir="${ROOT_DIR}/bin/utils"
  config_converter="${utils_dir}/config-converter/src/cli.js"
  jq="${utils_dir}/njq/src/index.js"

  node "${config_converter}" yaml read "${INSTANCE_DIR}/zowe.yaml" | node "${jq}" -r "${key}"
}

update_zowe_instance_variable(){                                                                            
  variable_name=$1
  variable_value=$2
  is_append=$3 # if false then the value of the given variable_name will be replaced, append the value if true

  if [ "${is_append}" != "true" ]; then
    is_append=false # default value is false
  fi

  variable_name_exists=$(grep "^ *${variable_name}=" ${INSTANCE_DIR}/instance.env)

  if [ -z "${variable_name_exists}" ]; then
    # check if we have line feed at the end of instance.env and add if missing
    # otherwise we may append to another variable at the end of the file
    have_line_feed=$(tail -c 1 ${INSTANCE_DIR}/instance.env | wc -l)
    if [ ${have_line_feed} -eq 0 ]; then
      echo "" >> ${INSTANCE_DIR}/instance.env
    fi
    echo "${variable_name}=${variable_value}" >> ${INSTANCE_DIR}/instance.env
  else
    curr_variable_value=$(read_zowe_instance_variable "${variable_name}")
    # FIXME: we have risks if value has "#" character
    if [ -n "${curr_variable_value}" ]; then
      if [ "${is_append}" = "false" ]; then
        sed -e "s#^ *${variable_name}=${curr_variable_value}#${variable_name}=${variable_value}#" ${INSTANCE_DIR}/instance.env > ${INSTANCE_DIR}/instance.env.tmp
        mv ${INSTANCE_DIR}/instance.env.tmp ${INSTANCE_DIR}/instance.env
      else
        # Ensures that the bin directory of the component is included into the instance.env once (Avoids duplication if same component is installed twice)
        if [[ $(echo ${curr_variable_value} | grep ${variable_value}) = "" ]]; then
          sed -e "s#^ *${variable_name}=${curr_variable_value}#${variable_name}=${curr_variable_value},${variable_value}#" ${INSTANCE_DIR}/instance.env > ${INSTANCE_DIR}/instance.env.tmp
          mv ${INSTANCE_DIR}/instance.env.tmp ${INSTANCE_DIR}/instance.env
        fi
      fi
    else
        sed -e "s#^ *${variable_name}=#${variable_name}=${variable_value}#" ${INSTANCE_DIR}/instance.env > ${INSTANCE_DIR}/instance.env.tmp
        mv ${INSTANCE_DIR}/instance.env.tmp ${INSTANCE_DIR}/instance.env
    fi
  fi
}

update_yaml_variable() {
  utils_dir="${ROOT_DIR}/bin/utils"
  config_converter="${utils_dir}/config-converter/src/cli.js"
  
  node "${config_converter}" yaml update "${1}" "${2}" "${3}"

  ensure_zowe_yaml_encoding "${1}"
}

delete_yaml_variable() {
  utils_dir="${ROOT_DIR}/bin/utils"
  config_converter="${utils_dir}/config-converter/src/cli.js"
  
  node "${config_converter}" yaml delete "${1}" "${2}"

  ensure_zowe_yaml_encoding "${1}"
}

update_zowe_yaml_variable() {
  update_yaml_variable "${INSTANCE_DIR}/zowe.yaml" "${1}" "${2}"
}

# prepare all environment variables used in containerization
# these variables shouldn't be modified
prepare_container_runtime_environments() {
  if [ -z "${NODE_HOME}" ]; then
    export NODE_HOME=$(detect_node_home)
  fi

  # write tmp to here so we can enable readOnlyRootFilesystem
  if [ -d "${INSTANCE_DIR}/tmp" ]; then
    export TMPDIR=${INSTANCE_DIR}/tmp
    export TMP=${INSTANCE_DIR}/tmp
  fi
  # these 2 important variables will be overwritten from what it may have been configured
  export ZOWE_EXPLORER_HOST=$(get_sysname)
  export ZOWE_IP_ADDRESS=$(get_ipaddress "${ZOWE_EXPLORER_HOST}")
  if [ -z "${ZWE_POD_NAMESPACE}" -a -f /var/run/secrets/kubernetes.io/serviceaccount/namespace ]; then
    # try to detect ZWE_POD_NAMESPACE, this requires automountServiceAccountToken to be true
    ZWE_POD_NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null)
  fi
  if [ -z "${ZWE_POD_NAMESPACE}" ]; then
    # fall back to default value
    export ZWE_POD_NAMESPACE=zowe
  fi
  if [ -z "${ZWE_POD_CLUSTERNAME}" ]; then
    # fall back to default value
    export ZWE_POD_CLUSTERNAME=cluster.local
  fi
  # in kubernetes, replace it with pod dns name
  export ZOWE_EXPLORER_HOST="$(echo "${ZOWE_IP_ADDRESS}" | sed -e 's#\.#-#g').${ZWE_POD_NAMESPACE}.pod.${ZWE_POD_CLUSTERNAME}"
  # this should be same as ZOWE_EXPLORER_HOST, app-server is using this variable
  export ZWE_INTERNAL_HOST=${ZOWE_EXPLORER_HOST}
  # kubernetes gateway service internal dns name
  export GATEWAY_HOST=gateway-service.${ZWE_POD_NAMESPACE}.svc.${ZWE_POD_CLUSTERNAME}

  # overwrite ZWE_DISCOVERY_SERVICES_LIST from ZWE_DISCOVERY_SERVICES_REPLICAS
  ZWE_DISCOVERY_SERVICES_REPLICAS=$(echo "${ZWE_DISCOVERY_SERVICES_REPLICAS}" | tr -cd '[[:digit:]]' | tr -d '[[:space:]]')
  if [ -z "${ZWE_DISCOVERY_SERVICES_REPLICAS}" ]; then
    export ZWE_DISCOVERY_SERVICES_REPLICAS=1
  fi
  discovery_index=0
  export ZWE_DISCOVERY_SERVICES_LIST=
  while [ $discovery_index -lt ${ZWE_DISCOVERY_SERVICES_REPLICAS} ]; do
    if [ -n "${ZWE_DISCOVERY_SERVICES_LIST}" ]; then
      ZWE_DISCOVERY_SERVICES_LIST="${ZWE_DISCOVERY_SERVICES_LIST},"
    fi
    ZWE_DISCOVERY_SERVICES_LIST="${ZWE_DISCOVERY_SERVICES_LIST}https://discovery-${discovery_index}.discovery-service.${ZWE_POD_NAMESPACE}.svc.${ZWE_POD_CLUSTERNAME}:${DISCOVERY_PORT}/eureka/"
    discovery_index=`expr $discovery_index + 1`
  done

  # read ZOWE_CONTAINER_COMPONENT_ID from component manifest
  # /component is hardcoded path we asked for in conformance
  if [ -z "${ZOWE_CONTAINER_COMPONENT_ID}" ]; then
    export ZOWE_CONTAINER_COMPONENT_ID=$(read_component_manifest /component '.name')
  fi
  export ZWE_LAUNCH_COMPONENTS="${ZOWE_CONTAINER_COMPONENT_ID}"
  export LAUNCH_COMPONENTS="${ZOWE_CONTAINER_COMPONENT_ID}"

  # FIXME: below variables are different from HA configuration, we should consolidate and make them consistent
  # in HA setup, this is used to point where is gateway accessible from internal
  # export EUREKA_INSTANCE_HOMEPAGEURL=https://${GATEWAY_HOST}:${GATEWAY_PORT}/
  unset EUREKA_INSTANCE_HOMEPAGEURL
  # app-server can handle these variable correctly now, unset them
  unset ZWED_node_mediationLayer_server_gatewayHostname
  unset ZWED_node_mediationLayer_server_gatewayPort
  unset ZWED_node_mediationLayer_server_hostname
  unset ZWED_node_mediationLayer_server_port
  unset ZWED_node_mediationLayer_enabled
  unset ZWED_node_mediationLayer_cachingService_enabled
}
