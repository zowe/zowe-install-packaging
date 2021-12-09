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
    print_error_and_exit "Error ZWEL0131E: Cannot find java. Please define JAVA_HOME environment variable." "" 131
  fi

  ensure_java_is_on_path
}


validate_java_home() {
  if [ -z "${JAVA_HOME}" ]; then
    print_error "Cannot find java. Please define JAVA_HOME environment variable."
    return 1
  fi

  if [ ! -f "${JAVA_HOME}/bin/java" ]; then
    print_error "JAVA_HOME: ${JAVA_HOME}/bin does not point to a valid install of Java."
    return 1
  fi

  java_version=$("${JAVA_HOME}/bin/java" -version 2>&1) # Capture stderr to stdout, so we can print below if error
  java_version_rc=$?
  if [ ${java_version_rc} -ne 0 ]; then
    print_error "Java version check failed with return code: ${java_version_rc}: ${java_version}"
    return 1
  fi

  # As we know the java -version command works then strip out the line we need
  java_version_short=$(echo "${java_version}" | grep ^"java version" | sed -e "s/java version //g"| sed -e "s/\"//g")
  if [[ $java_version_short == "" ]]; then
    java_version_short=$(echo "${java_version}" | grep ^"openjdk version" | sed -e "s/openjdk version //g"| sed -e "s/\"//g")
  fi
  java_major_version=$(echo "${java_version_short}" | cut -d '.' -f 1)
  java_minor_version=$(echo "${java_version_short}" | cut -d '.' -f 2)

  too_low=
  if [ ${java_major_version} -lt 1 ]; then
    too_low="true"
  elif [ ${java_major_version} -eq 1 -a ${java_minor_version} -lt 8 ]; then
    too_low="true"
  fi
  if [ "${too_low}" = "true" ]; then
    print_error "Java ${java_version_short} is less than the minimum level required of Java 8 (1.8.0)."
    return 1
  fi
  print_debug "Java ${java_version_short} is supported."
}
