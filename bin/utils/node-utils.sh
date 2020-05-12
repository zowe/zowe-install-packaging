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

#TODO LATER - provide flag that toggles all functions to error if they exit non-zero?

ensure_node_is_on_path() {
  if [[ ":$PATH:" != *":$NODE_HOME/bin:"* ]]
  then
    echo "Appending NODE_HOME/bin to the PATH..."
    export PATH=$PATH:$NODE_HOME/bin
  fi
}


# TODO - refactor this into shared script?
# Note requires #ROOT_DIR to be set to use errror.sh, otherwise falls back to stderr
print_error_message() {
  message=$1
  error_path=${ROOT_DIR}/scripts/utils/error.sh
  if [[ -f "${error_path}" ]]
  then
    . ${error_path} $message
  else 
    echo $message 1>&2
  fi
}