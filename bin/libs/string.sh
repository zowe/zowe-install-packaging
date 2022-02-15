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

  echo "${str}" | sed "s/^/${pad}/"
}

###############################
# Padding string of every line of a multiple-line string
#
# @param string   optional string
file_padding_left() {
  file="${1}"
  pad="${2}"

  cat "${file}" | sed "s/^/${pad}/"
}

###############################
# Remove / if it's the last character of the input string
#
# @param string   optional string
remove_trailing_slash() {
  if [ $# -eq 0 ]; then
    read input
  else
    input="${1}"
  fi

  echo "${input}" | sed 's#/$##'
}

###############################
# Base64 encode a string
#
# Note: this tool requires uuencode.
#
# @param string   optional string
base64_encode() {
  uuencode -m "${1}" dummy | sed '1d;$d' | tr -d '\n'
}

###############################
# Check if an item is part of comma separated list
#
# @param string   list separated by <separator>
# @param string   the item to check
# @param string   separator, default value is comman (,).
item_in_list() {
  list="${1}"
  item="${2}"
  separator="${3:-,}"

  OLDIFS=$IFS
  IFS="${separator}"
  found=
  for one in ${list}; do
    if [ "${one}" = "${item}" ]; then
      found=true
    fi
  done
  IFS=$OLDIFS

  printf "${found}"
}

