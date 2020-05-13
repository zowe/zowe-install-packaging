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

# Takes in two parameters - the file that should be expanded and a string of the variable name that should be set in return
get_full_path() {
  file=$1
  # If the value starts with a ~ for the home variable then evaluate it
  file=`sh -c "echo $file"`
  # If the path is relative, then expand it
  if [[ "$file" != /* ]]
  then
    file=$PWD/$file
  fi
  eval $2="${file}"
}

# Takes in two parameters - the file and the directory we want to check it isn't in
# Returns 0 if valid, 1 if not
validate_file_not_in_directory() {
  get_full_path $1 file
  directory=$2

  #zip-1172: Ensure trailing slash on root-dir to stop sibiling matches
  echo "${directory}" | grep '/$' 1> /dev/null
  if [[ $? -ne 0 ]]
  then
    directory="${directory}/"
  fi
  echo "${file}" | grep '/$' 1> /dev/null
  if [[ $? -ne 0 ]]
  then
    file="${file}/"
  fi

  if [[ ${file} == "${directory}"* ]]
  then
    return 1
  fi
}

validate_directory_is_accessible() {
  directory=$1
  if [[ ! -d ${directory} ]]
  then
    print_error_message "Directory '${directory}' doesn't exist, or is not accessible to ${USER}. If the directory exists, check all the parent directories have traversal permission (execute)"
    return 1
  fi
  return 0
}

validate_directory_is_writable() {
  directory=$1
  validate_directory_is_accessible $directory
  accessible_rc=$?
  if [[ ${accessible_rc} -eq 0 ]]
  then	
    if [[ ! -w ${directory} ]]
    then	
      print_error_message "Directory '${directory}' does not have write access"	
      return 1
    fi
  else
    return accessible_rc
  fi
}

# TODO LATER - refactor this into shared script
# Note requires #ROOT_DIR to be set to use error.sh, otherwise falls back to stderr
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