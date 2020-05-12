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

# Takes in two parameters - the name of the variable (for error messaging) and the value
validate_variable_is_set() {
  variable_name=$1
  value=$2
  if [[ -z "${value}" ]]
  then
    print_error_message "${variable_name} is empty"
    return 1
  fi
}

# ZOWE_PREFIX + instance - should be <=6 char long and exist.
# TODO - any lower bound (other than 0)?
# Requires ZOWE_PREFIX to be set as a shell variable
validate_zowe_prefix() {
  validate_variable_is_set "ZOWE_PREFIX" "${ZOWE_PREFIX}"
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
    return prefix_set_rc
  fi
}

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