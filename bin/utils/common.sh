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

#TODO LATER - do we want to provide a ENV_VAR flag that toggles whether errors are printed or not?

print_error_message() {
  message=$1
  #output an error and add to the count
  if [ -z "${ERRORS_FOUND}" ];
  then
    ERRORS_FOUND=0
  fi

  # echo error to standard out and err
  echo "Error ${ERRORS_FOUND}: ${message}"
  echo "Error ${ERRORS_FOUND}: ${message}" 1>&2
  let "ERRORS_FOUND=${ERRORS_FOUND}+1"
}