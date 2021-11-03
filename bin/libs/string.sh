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

trim() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | xargs
}

sanitize_alphanum() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | sed 's/[^a-zA-Z0-9]/_/g'
}

sanitize_alpha() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | sed 's/[^a-zA-Z]/_/g'
}

sanitize_num() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | sed 's/[^0-9]/_/g'
}

lower_case() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | tr '[:upper:]' '[:lower:]'
}

upper_case() {
  if [ $# -eq 0 ]; then
    read input
  else
    input=${1}
  fi

  echo "${input}" | tr '[:lower:]' '[:upper:]'
}

padding() {
  str=$1
  pad=$2

  while read -r line; do
    echo "${pad}${line}"
  done <<EOF
$(echo "${str}")
EOF
}
