#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2021
################################################################################

################################################################################
# IMPORTANT: all functions in this utility script requires running on z/OS

###############################
# Get file encoding from z/OS USS tagging
#
# @param string   file name
# output          USS encoding if exists in upper case
zos_get_file_tag_encoding() {
  file=$1
  # m ISO8859-1   T=off <file>
  # - untagged    T=off <file>
  ls -T "$file" | awk '{print $2;}' | tr '[:lower:]' '[:upper:]'
}
