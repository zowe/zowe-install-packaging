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
    export PATH=${NODE_HOME}/bin:${PATH}
  fi
}

detect_node_home() {
  # do we have which?
  node_home=$(which node 2>/dev/null)
  if [ -z "${node_home}" ]; then
    (
      IFS=:
      for p in ${PATH}; do
        if [ -f "${p}/node" ]; then
          cd "${p}/.."
          pwd
          break
        fi
      done
    )
  else
    echo "${node_home}"
  fi
}

require_node() {
  if [ -z "${NODE_HOME}" ]; then
    export NODE_HOME=$(detect_node_home)
  fi

  if [ -z "${NODE_HOME}" ]; then
    print_error_and_exit "Error ZWES0130E: Cannot find node. Please define NODE_HOME environment variable." "" 130
  fi

  ensure_node_is_on_path
}
