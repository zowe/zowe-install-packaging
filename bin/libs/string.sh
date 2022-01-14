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

###############################
# Trim string (remove all spaces at the beginning or end of the string)
#
# @param string   optional string
trim() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | xargs
}

###############################
# Sanitize a string by converting all non-alphanum letters to underscore
#
# @param string   optional string
sanitize_alphanum() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | sed 's/[^a-zA-Z0-9]/_/g'
}

###############################
# Sanitize a string by converting all non-alphabetical letters to underscore
#
# @param string   optional string
sanitize_alpha() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | sed 's/[^a-zA-Z]/_/g'
}

###############################
# Sanitize a string by converting all non-numeric letters to underscore
#
# @param string   optional string
sanitize_num() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | sed 's/[^0-9]/_/g'
}

###############################
# Convert string to lower case
#
# @param string   optional string
lower_case() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | tr '[:upper:]' '[:lower:]'
}

###############################
# Convert string to upper case
#
# @param string   optional string
upper_case() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | tr '[:lower:]' '[:upper:]'
}

###############################
# Padding string of every line of a multiple-line string
#
# @param string   optional string
padding_left() {
  str="${1}"
  pad="${2}"

  while read -r line; do
    echo "${pad}${line}"
  done <<EOF
$(echo "${str}")
EOF
}

###############################
# Remove / if it's the last character of the input string
#
# @param string   optional string
remove_trailing_slash() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | sed 's#/$##'
}
