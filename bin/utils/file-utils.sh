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