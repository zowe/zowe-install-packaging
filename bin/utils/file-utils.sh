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
elif [[ $0 == "file-utils.sh" ]] #Not called by source
then
  export utils_dir=$(cd $(dirname $0);pwd)
else
  echo "Could not work out the path to the utils directory. Please 'export ZOWE_ROOT_DIR=<zowe-root-directory>' before running." 1>&2
  return 1
fi

# Source common util functions
. ${utils_dir}/common.sh

# Takes in the file that should be expanded and echos out the result, which the caller needs to read
get_full_path() {
  file=$1
  # If the value starts with a ~ for the home variable then evaluate it
  file=`sh -c "echo $file"`
  # If the path is relative, then expand it
  if [[ "$file" != /* ]]
  then
    file=$PWD/$file
  fi
  echo $file
}

# Takes in two parameters - the file and the directory we want to check it isn't in
# Returns 0 if valid, 1 if not
validate_file_not_in_directory() {
  file=$(get_full_path "$1")
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