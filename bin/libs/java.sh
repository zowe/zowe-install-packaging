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
    export PATH="${JAVA_HOME}/bin:${PATH}"
  fi
}

shell_read_yaml_java_home() {
  yaml="${1}"

  java_home=$(shell_read_yaml_config "${yaml}" 'java' 'home')
  # validate NODE_HOME
  result=$(validate_java_home "${java_home}" 2>/dev/null)
  code=$?
  if [ ${code} -ne 0 ]; then
    # incorrect NODE_HOME, reset and try again
    # this could be caused by failing to read java.home correctly from zowe.yaml
    java_home=
  fi

  if [ -n "${java_home}" ]; then
    printf "${java_home}"
  fi
}

detect_java_home() {
  java_home=

  # do we have which?
  java_bin_home=$(which java 2>/dev/null)
  if [ -n "${java_bin_home}" ]; then
    # extract java home from result like: /var/jdk/bin/java
    java_home=$(dirname "$(dirname "${java_bin_home}")")
  fi

  # fall back to check PATH
  java_home=$(which java 2>/dev/null)
  if [ -z "${java_home}" ]; then
    java_home=$(
      IFS=:
      for p in ${PATH}; do
        if [ -f "${p}/java" ]; then
          cd "${p}/.."
          pwd
          break
        fi
      done
    ) 
  fi

  # fall back to the most well-known java path
  if [ -z "${java_home}" -a -f /usr/lpp/java/J8.0_64/bin/java ]; then
    java_home=/usr/lpp/java/J8.0_64
  fi

  if [ -n "${java_home}" ]; then
    printf "${java_home}"
  fi
}

require_java() {
  # prepare the JAVA_HOME in zowe.yaml
  if [ -n "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
    custom_java_home="$(shell_read_yaml_java_home "${ZWE_CLI_PARAMETER_CONFIG}")"
    if [ -n "${custom_java_home}" ]; then
      export JAVA_HOME="${custom_java_home}"
    fi
  fi
  if [ -z "${JAVA_HOME}" ]; then
    export JAVA_HOME="$(detect_java_home)"
  fi

  if [ -z "${JAVA_HOME}" ]; then
    print_error_and_exit "Error ZWEL0122E: Cannot find java. Please define JAVA_HOME environment variable." "" 122
  fi

  ensure_java_is_on_path
}


validate_java_home() {
  java_home="${1:-${JAVA_HOME}}"

  if [ -z "${java_home}" ]; then
    print_error "Cannot find java. Please define JAVA_HOME environment variable."
    return 1
  fi

  if [ ! -f "${java_home}/bin/java" ]; then
    print_error "JAVA_HOME: ${java_home}/bin does not point to a valid install of Java."
    return 1
  fi

  java_version=$("${java_home}/bin/java" -version 2>&1) # Capture stderr to stdout, so we can print below if error
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

  print_debug "Java check is successful."
}

get_java_pkcs12_keystore_flag() {
  java_version=$("${JAVA_HOME}/bin/java" -version 2>&1) # Capture stderr to stdout, so we can print below if error


  # As we know the java -version command works then strip out the line we need
  java_version_short=$(echo "${java_version}" | grep ^"java version" | sed -e "s/java version //g"| sed -e "s/\"//g")
  if [[ $java_version_short == "" ]]; then
    java_version_short=$(echo "${java_version}" | grep ^"openjdk version" | sed -e "s/openjdk version //g"| sed -e "s/\"//g")
  fi
  java_major_version=$(echo "${java_version_short}" | cut -d '.' -f 1)
  java_minor_version=$(echo "${java_version_short}" | cut -d '.' -f 2)
  java_fix_version=$(echo "${java_version_short}" | cut -d '_' -f 2)

  if [ ${java_major_version} -eq 1 -a ${java_minor_version} -eq 8 ]; then
    if [ ${java_fix_version} -lt 341 ]; then
      printf " "
    elif [ ${java_fix_version} -lt 361 ]; then
      printf " -J-Dkeystore.pkcs12.certProtectionAlgorithm=PBEWithSHAAnd40BitRC2 -J-Dkeystore.pkcs12.certPbeIterationCount=50000 -J-Dkeystore.pkcs12.keyProtectionAlgorithm=PBEWithSHAAnd3KeyTripleDES -J-Dkeystore.pkcs12.keyPbeIterationCount=50000 "
    else
      printf " -J-Dkeystore.pkcs12.legacy "
    fi
  elif [ ${java_major_version} -eq 1 -a ${java_minor_version} -gt 8 ]; then
    printf " -J-Dkeystore.pkcs12.legacy "
  else
    printf " "  
  fi
}

