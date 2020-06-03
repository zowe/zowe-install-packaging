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

# TODO LATER - anyway to do this better?
# Try and work out where we are even if sourced
echo one
if [[ -n ${INSTALL_DIR} ]]
then
  export utils_dir="${INSTALL_DIR}/bin/utils"
elif [[ -n ${ZOWE_ROOT_DIR} ]]
then
  export utils_dir="${ZOWE_ROOT_DIR}/bin/utils"
elif [[ -n ${ROOT_DIR} ]]
then
  export utils_dir="${ROOT_DIR}/bin/utils"
elif [[ $0 == "java-utils.sh" ]] #Not called by source
then
  export utils_dir=$(cd $(dirname $0);pwd)
else
  echo "Could not work out the path to the utils directory. Please 'export ZOWE_ROOT_DIR=<zowe-root-directory>' before running." 1>&2
  return 1
fi
echo two 
# Source common util functions
. ${utils_dir}/common.sh
echo three
ensure_java_is_on_path() {
  if [[ ":$PATH:" != *":$JAVA_HOME/bin:"* ]]
  then
    print_message "Appending JAVA_HOME/bin to the PATH..."
    export PATH=$PATH:$JAVA_HOME/bin
  fi
}
echo four
validate_java_home() {
  echo "TEST javahome"
  echo $JAVA_HOME
  validate_java_home_not_empty
  java_empty_rc=$?
  if [[ ${java_empty_rc} -ne 0 ]]
  then
    return ${java_empty_rc}
  fi

  ls ${JAVA_HOME}/bin | grep java$ > /dev/null
  echo "here $?"
  if [[ $? -ne 0 ]];
  then
    print_error_message "JAVA_HOME: ${JAVA_HOME}/bin does not point to a valid install of Java"
    return 1
  fi
  java_version_output=$(${JAVA_HOME}/bin/java -version 2>&1 ) # Capture stderr to stdout, so we can print below if error
  java_version_rc=$?
  if [[ ${java_version_rc} -ne 0 ]]
  then
    print_error_message "Java version check failed with return code: ${java_version_rc}, error: ${java_version_output}"
    return 1
  fi
  echo "one $java_version_output"
  echo $(${JAVA_HOME}/bin/java -version)

  # As we know the java -version command works then strip out the line we need
  java_version_output=$(${JAVA_HOME}/bin/java -version 2>&1 | grep ^"openjdk version")
  echo "two $java_version_output"

  check_java_version "${java_version_output}"
  java_version_rc=$?
  if [[ ${java_version_rc} -ne 0 ]]
  then
    return ${java_version_rc}
  fi
}
echo five
validate_java_home_not_empty() {
  echo "do we get here?"
  . ${utils_dir}/zowe-variable-utils.sh
  validate_variable_is_set "JAVA_HOME"
  echo "this $JAVA_HOME"
  echo $?
  return $?
}
echo six
# Given a java version string from the `java -version` command, checks if it is valid
check_java_version() {
  java_version_output=$1
  java_version=$(echo ${java_version_output} | sed -e "s/openjdk version //g"| sed -e "s/\"//g")
  echo ${java_version_output}
  echo ${java_version}
  echo $JAVA_HOME
  echo "tthhrreee"
  java_major_version=$(echo ${java_version} | cut -d '.' -f 1)
  java_minor_version=$(echo ${java_version} | cut -d '.' -f 2)
  echo ${java_minor_version}
  echo "yeeter"
  echo ${java_major_version}
  too_low=""
  if [[ ${java_major_version} -lt 1 ]] #Should never get here
  then
    too_low="true"
  elif [[ ${java_major_version} -eq 1 ]] && [[ ${java_minor_version} -le 8 ]]
  then
    too_low="true"
  fi

  if [[ ${too_low} == "true" ]]
  then
    print_error_message "Java Version ${java_version} is less than the minimum level required of Java 8 (1.8.0)"
    return 1
  else
    log_message "Java version ${java_version} is supported"
  fi
}
echo seven
# TODO - how to test well given interaction and guess?
# Interactive function that checks if the current JAVA_HOME is valid and if not requests a user enters the java home path via command line
prompt_java_home_if_required() {
  # If JAVA_HOME not set, guess a default value
  if [[ -z ${JAVA_HOME} ]]
  then
    JAVA_HOME="/usr/lpp/java/J8.0_64"
  fi
  loop=1
  while [ ${loop} -eq 1 ]
  do
    loop=0 # only want to re-run if user re-prompts
    validate_java_home # Note - this outputs messages for errors found
    java_valid_rc=$?
    if [[ ${java_valid_rc} -ne 0 ]]
    then
      echo "Press Y or y to accept current java home '${JAVA_HOME}', or Enter to choose another location"
      read rep
      if [ "$rep" != "Y" ] && [ "$rep" != "y" ]
      then
        echo "Please enter a path to where java is installed.  This is the a directory that contains /bin/java "
        read JAVA_HOME
        loop=1
      fi
    fi
  done
  export JAVA_HOME=$JAVA_HOME
  log_message "  JAVA_HOME variable value=${JAVA_HOME}"
}
echo eight