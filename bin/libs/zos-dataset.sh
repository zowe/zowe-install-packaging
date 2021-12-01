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

is_data_set_exists() {
  ds=$1

  (cat "//'${ds}'" 1>/dev/null 2>&1)
  if [ $? -eq 0 ]; then
    echo "true"
  fi
}

# Check if data set exists using TSO command (listds)
#
# @param dsn     data set (or with member) name to check
# @return        0: exist
#                1: data set doesn't exist
#                2: data set member doesn't exist
# @output        tso listds label output
tso_is_data_set_exists() {
  ds=$1

  cmd="listds '${ds}' label"
  print_debug "- ${cmd}"
  result=$(tsocmd "${cmd}" 2>&1)
  code=$?
  echo "${result}"
  if [ ${code} -eq 0 ]; then
    print_debug "  * Succeeded"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    print_trace "$(padding_left "${result}" "    ")"
  else
    print_debug "  * Failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    print_error "$(padding_left "${result}" "    ")"

    not_in_catalog=$(echo "${result}" | grep 'NOT IN CATALOG')
    if [ -n "${not_in_catalog}" ]; then
      return 1
    fi
    member_not_found=$(echo "${result}" | grep 'MEMBER NAME NOT FOUND')
    if [ -n "${member_not_found}" ]; then
      return 2
    fi
    # some other error we don't know yet
    return 9
  fi

  return 0
}

create_data_set() {
  ds_name=$1
  ds_opts=$2

  print_debug "- ALLOCATE NEW DA(${ds_name}) ${ds_opts}"
  result=$(tsocmd "ALLOCATE NEW DA('${ds_name}') ${ds_opts}" 2>&1)
  code=$?
  if [ ${code} -eq 0 ]; then
    print_debug "  * Succeeded"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    print_trace "$(padding_left "${result}" "    ")"
  else
    print_debug "  * Failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    print_error "$(padding_left "${result}" "    ")"
  fi

  return ${code}
}

copy_to_data_set() {
  uss_file=$1
  ds_name=$2
  cp_opts=$3
  allow_overwrite=$4

  if [ "${allow_overwrite}" != "true" ]; then
    if [ "$(is_data_set_exists "//'${ds_name}'")" = "true" ]; then
      print_error_and_exit "Error ZWEL0133E: Data set ${ds_name} already exists" "" 133
    fi
  fi

  print_debug "- cp ${cp_opts} -v ${uss_file} //'${ds_name}'"
  result=$(cp ${cp_opts} -v "${uss_file}" "//'${ds_name}'" 2>&1)
  code=$?
  if [ ${code} -eq 0 ]; then
    print_debug "  * Succeeded"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    print_trace "$(padding_left "${result}" "    ")"
  else
    print_debug "  * Failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    print_error "$(padding_left "${result}" "    ")"
  fi

  return ${code}
}

data_set_copy_to_data_set() {
  hlq=$1
  ds_from=$2
  ds_to=$3
  allow_overwrite=$4

  if [ "${allow_overwrite}" != "true" ]; then
    if [ "$(is_data_set_exists "//'${ds_to}'")" = "true" ]; then
      print_error_and_exit "Error ZWEL0133E: Data set ${ds_to} already exists" "" 133
    fi
  fi

  cmd="exec '${hlq}.${ZWE_DS_SZWCLIB}(MCOPYSHR)' '${ds_from} ${ds_to}'"
  print_debug "- tsocmd ${cmd}"
  result=$(tsocmd "${cmd}" 2>&1)
  code=$?
  if [ ${code} -eq 0 ]; then
    print_debug "  * Succeeded"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    print_trace "$(padding_left "${result}" "    ")"
  else
    print_debug "  * Failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    print_error "$(padding_left "${result}" "    ")"
  fi

  return ${code}
}

# List users of a data set
#
# @param dsn     data set name to check
# @return        0: no users
#                1: there are some users
# @output        output of operator command "d grs"
list_data_set_user() {
  opercmd=${ZWE_zowe_runtimeDirectory}/bin/utils/opercmd.rex

  cmd="D GRS,RES=(*,$1)"
  print_debug "- opercmd ${cmd}"
  result=$($opercmd "${cmd}")
  print_trace "  * Exit code: ${code}"
  print_trace "  * Output:"
  print_trace "$(padding_left "${result}" "    ")"

  # example outputs:
  #
  # server    2021040  22:29:30.60             ISF031I CONSOLE MYCONS ACTIVATED
  # server    2021040  22:29:30.60            -D GRS,RES=(*,IBMUSER.PARMLIB)
  # server    2021040  22:29:30.60             ISG343I 22.29.30 GRS STATUS 336
  #                                            S=SYSTEM  SYSDSN   IBMUSER.PARMLIB
  #                                            SYSNAME        JOBNAME         ASID     TCBADDR   EXC/SHR    STATUS
  #                                            server    ZWESISTC           0045       006FED90   SHARE      OWN
  # ISF754I Command 'SET CONSOLE MYCONS' generated from associated variable ISFCONS.
  # ISF776I Processing started for action 1 of 1.
  # ISF769I System command issued, command text: D GRS,RES=(*,IBMUSER.PARMLIB).
  # ISF766I Request completed, status: COMMAND ISSUED.
  #
  # example output:
  #
  # server    2021040  22:31:07.32             ISF031I CONSOLE MYCONS ACTIVATED
  # server    2021040  22:31:07.32            -D GRS,RES=(*,IBMUSER.LOADLIB)
  # server    2021040  22:31:07.32             ISG343I 22.31.07 GRS STATUS 363
  #                                            NO REQUESTORS FOR RESOURCE  *        IBMUSER.LOADLIB
  # ISF754I Command 'SET CONSOLE MYCONS' generated from associated variable ISFCONS.
  # ISF776I Processing started for action 1 of 1.
  # ISF769I System command issued, command text: D GRS,RES=(*,IBMUSER.LOADLIB).
  # ISF766I Request completed, status: COMMAND ISSUED.

  no_requestors=$(echo "${result}" | grep 'NO REQUESTORS FOR RESOURCE')
  if [ -n "${no_requestors}" ]; then
    return 0
  fi

  return 1
}

# Delete data set
#
# @param dsn     data set (or with member) name to delete
# @return        0: exist
#                1: data set doesn't exist
#                2: data set member doesn't exist
#                3: data set is in use
# @output        tso listds label output
delete_data_set() {
  ds=$1

  cmd="delete '${ds}'"
  print_debug "- tsocmd ${cmd}"
  result=$(tsocmd "${cmd}" 2>&1)
  code=$?
  if [ ${code} -eq 0 ]; then
    print_debug "  * Succeeded"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    print_trace "$(padding_left "${result}" "    ")"
  else
    print_debug "  * Failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    print_error "$(padding_left "${result}" "    ")"

    not_in_catalog=$(echo "${result}" | grep 'NOT IN CATALOG')
    if [ -n "${not_in_catalog}" ]; then
      return 1
    fi
    not_found=$(echo "${result}" | grep 'NOT FOUND')
    if [ -n "${not_found}" ]; then
      return 2
    fi
    in_use=$(echo "${result}" | grep 'IN USE BY')
    if [ -n "${in_use}" ]; then
      return 3
    fi
    # some other error we don't know yet
    return 9
  fi

  return 0
}
