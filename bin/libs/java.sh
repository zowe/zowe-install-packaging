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

ensure_java_is_on_path() {
  if [[ ":${PATH}:" != *":${JAVA_HOME}/bin:"* ]]; then
    export PATH=${JAVA_HOME}/bin:${PATH}
  fi
}

detect_java_home() {
  # do we have which?
  java_home=$(which java 2>/dev/null)
  if [ -z "${java_home}" ]; then
    (
      IFS=:
      for p in ${PATH}; do
        if [ -f "${p}/node" ]; then
          cd "${p}/.."
          pwd
          break
        fi
      done
    )
  else
    echo "${java_home}"
  fi
}

require_java() {
  if [ -z "${JAVA_HOME}" ]; then
    export JAVA_HOME=$(detect_java_home)
  fi

  if [ -z "${JAVA_HOME}" ]; then
    print_error_and_exit "Error ZWEI0131E: Cannot find java. Please define JAVA_HOME environment variable." "" 131
  fi

  ensure_java_is_on_path
}
