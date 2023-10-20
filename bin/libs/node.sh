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

# these are shell environments related to node.js we want to enforce in all cases

# enforce encoding of stdio/stdout/stderr
# sometimes /dev/tty* ($SSH_TTY) are not configured properly, for example tagged as binary or wrong encoding
export NODE_STDOUT_CCSID=1047
export NODE_STDERR_CCSID=1047
export NODE_STDIN_CCSID=1047

# Workaround Fix for node 8.16.1 that requires compatibility mode for untagged files
export __UNTAGGED_READ_MODE=V6

ensure_node_is_on_path() {
  if [[ ":${PATH}:" != *":${NODE_HOME}/bin:"* ]]; then
    export PATH="${NODE_HOME}/bin:${PATH}"
  fi
}

shell_read_yaml_node_home() {
  yaml="${1}"
  skip_validate="${2}"

  node_home=$(shell_read_yaml_config "${yaml}" 'node' 'home')

  if [ "${skip_validate}" = "true" ]; then
    # validate NODE_HOME, we can ignore errors here, only need exit code
    result=$(validate_node_home "${node_home}" 2>/dev/null)
    code=$?
    if [ ${code} -ne 0 ]; then
      # incorrect NODE_HOME, reset and try again
      # this could be caused by failing to read node.home correctly from zowe.yaml
      node_home=
    fi
  fi

  if [ -n "${node_home}" ]; then
    printf "${node_home}"
  fi
}

detect_node_home() {
  node_home=

  # do we have which?
  node_bin_home=$(which node 2>/dev/null)
  if [ -n "${node_bin_home}" ]; then
    # extract node home from result like: /var/nodejs/node-v14.16.0-os390-s390x-202103142315/bin/node
    node_home=$(dirname "$(dirname "${node_bin_home}")")
  fi

  # fall back to check PATH
  if [ -z "${node_home}" ]; then
    node_home=$(
      IFS=:
      for p in ${PATH}; do
        if [ -f "${p}/node" ]; then
          cd "${p}/.."
          pwd
          break
        fi
      done
    )
  fi

  if [ -n "${node_home}" ]; then
    printf "${node_home}"
  fi
}

require_node() {
  # prepare the NODE_HOME in zowe.yaml
  if [ -n "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
    custom_node_home=$(shell_read_yaml_node_home "${ZWE_CLI_PARAMETER_CONFIG}")
    if [ -n "${custom_node_home}" ]; then
      export NODE_HOME="${custom_node_home}"
    fi
  fi
  if [ -z "${NODE_HOME}" ]; then
    export NODE_HOME=$(detect_node_home)
  fi

  if [ -z "${NODE_HOME}" ]; then
    print_error_and_exit "Error ZWEL0121E: Cannot find node. Please define NODE_HOME environment variable." "" 121
  fi

  ensure_node_is_on_path
}

validate_node_home() {
  node_home="${1:-${NODE_HOME}}"

  if [ -z "${node_home}" ]; then
    print_error "Cannot find node. Please define NODE_HOME environment variable."
    return 1
  fi

  if [ ! -f "${node_home}/bin/node" ]; then
    print_error "NODE_HOME: ${node_home}/bin does not point to a valid install of Node."
    return 1
  fi

  node_version=$("${node_home}/bin/node" --version 2>&1) # Capture stderr to stdout, so we can print below if error
  node_version_rc=$?
  if [ ${node_version_rc} -ne 0 ]; then
    print_error "Node version check failed with return code: ${node_version_rc}: ${node_version}"
    return 1
  fi
  node_major_version=$(echo ${node_version} | cut -d '.' -f 1 | cut -d 'v' -f 2)
  node_minor_version=$(echo ${node_version} | cut -d '.' -f 2)
  node_fix_version=$(echo ${node_version} | cut -d '.' -f 3)

  # check node version
  if [ "${node_version}" = "v18.12.1" ]; then
    print_error "Node ${node_version} specifically is not compatible with Zowe. Please use a different version. See https://github.com/ibmruntimes/node-zos/issues/21 for more details."
    return 1
  fi
  
  if [ ${node_major_version} -lt 16 ]; then
    print_error "Node ${node_version} is less than the minimum level required of v14+."
    return 1
  fi
  print_debug "Node ${node_version} is supported."

  node_ok=$("${node_home}/bin/node" -e "console.log('ok')" 2>&1)
  node_ok_rc=$?
  if [ "${node_ok}" != "ok" -o ${node_ok_rc} -ne 0 ]; then
    print_error "${node_home}/bin/node is not functioning correctly (exit code ${node_ok_rc}): ${node_ok}"
    return 1
  fi

  print_debug "Node check is successful."
}
