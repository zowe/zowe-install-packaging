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
# Get file encoding from z/OS USS tagging
#
# @param string   file name
# output          USS encoding if exists in upper case
get_file_encoding() {
  file=$1
  # m ISO8859-1   T=off <file>
  # - untagged    T=off <file>
  ls -T "${file}" | awk '{print $2;}' | upper_case
}

###############################
# Detect and verify file encoding
#
# This function will try to verify file encoding by reading sample string.
#
# Note: this function always exits with 0. Depends on the cases, the output is
#       confirmed encoding to stdout.
#       - file is already tagged: the output will be the encoding tag,
#       - file is not tagged:
#         - expected encoding is auto: the output will be one of IBM-1047, 
#                 ISO8859-1, IBM-850 based on the guess. Output is empty if none
#                 of those encodings are correct.
#         - expected encoding is not auto: the output will be same as expected
#                 encoding if it's correct. otherwise output will be empty.
#
# Example:
# - detect manifest encoding by checking result "name"
#   detect_file_encoding "/path/to/zowe/components/my-component/manifest.yaml" "name"
#
# @param string   path to file to verify
# @param string   expected sample string to verify result
# @param string   expected encoding. This is optional, and default value is "auto".
#                 When this value is auto, the function will try to guess common
#                 encodings (IBM-1047, ISO8859-1, IBM-850). 
detect_file_encoding() {
  file_name=$1
  expected_sample=$2
  expected_encoding=$3

  expected_encoding_uc=$(echo "${expected_encoding}" | tr '[:lower:]' '[:upper:]')

  confirmed_encoding=

  current_tag=$(ls -T "${file_name}" | awk '{print $2}')
  if [ "${current_tag}" != "untagged" ]; then
    confirmed_encoding="${current_tag}"
  fi

  if [ -z "${confirmed_encoding}" ]; then
    if [ "${expected_encoding_uc}" = "IBM-1047" ]; then
      result=$(cat "${file_name}" | grep "${expected_sample}" 2>/dev/null)
      if [ -n "${result}" ]; then
        confirmed_encoding=IBM-1047
      fi
    elif [ "${expected_encoding_uc}" = "AUTO" -o -z "${expected_encoding_uc}" ]; then
      # check IBM-1047
      result=$(cat "${file_name}" | grep "${expected_sample}" 2>/dev/null)
      if [ -n "${result}" ]; then
        confirmed_encoding=IBM-1047
      fi
      # check common encodings
      common_encodings="ISO8859-1 IBM-850"
      for enc in ${common_encodings}; do
        if [ -z "${confirmed_encoding}" ]; then
          result=$(iconv -f "${enc}" -t IBM-1047 "${file_name}" | grep "${expected_sample}" 2>/dev/null)
          if [ -n "${result}" ]; then
            confirmed_encoding=${enc}
          fi
        fi
      done
    else
      result=$(iconv -f "${expected_encoding_uc}" -t IBM-1047 "${file_name}" | grep "${expected_sample}" 2>/dev/null)
      if [ -n "${result}" ]; then
        confirmed_encoding=${expected_encoding_uc}
      fi
    fi
  fi

  if [ -n "${confirmed_encoding}" ]; then
    echo "${confirmed_encoding}"
  fi
}
