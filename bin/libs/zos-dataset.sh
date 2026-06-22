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
  ds="${1}"

  (cat "//'${ds}'" 1>/dev/null 2>&1)
  if [ $? -eq 0 ]; then
    echo "true"
  fi
}

# Check if data set exists using TSO command (listds)
#
# @param dsn     data set (or with member) name to check
# @return        0: exist
#                1: data set is not in catalog
#                2: data set member doesn't exist
# @output        tso listds label output
tso_is_data_set_exists() {
  ds="${1}"

  cmd="listds '${ds}' label"
  print_debug "- ${cmd}"
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
  ds_name="${1}"
  ds_opts="${2}"

  result=$(tso_command "ALLOCATE NEW DA('${ds_name}') ${ds_opts}")
  return $?
}

copy_to_data_set() {
  uss_file="${1}"
  ds_name="${2}"
  cp_opts="${3}"
  allow_overwrite="${4}"

  if [ "${allow_overwrite}" != "true" ]; then
    if [ "$(is_data_set_exists "${ds_name}")" = "true" ]; then
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
  prefix="${1}"
  ds_from="${2}"
  ds_to="${3}"
  allow_overwrite="${4}"

  if [ "${allow_overwrite}" != "true" ]; then
    if [ "$(is_data_set_exists "${ds_to}")" = "true" ]; then
      print_error_and_exit "Error ZWEL0133E: Data set ${ds_to} already exists" "" 133
    fi
  fi

  cmd="exec '${prefix}.${ZWE_PRIVATE_DS_SZWEEXEC}(ZWEMCOPY)' '${ds_from} ${ds_to}'"
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
  result=$("${opercmd}" "${cmd}")
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
  ds="${1}"

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

is_data_set_sms_managed() {
  ds="${1}"

  # REF: https://www.ibm.com/docs/en/zos/2.3.0?topic=dscbs-how-found
  #      bit DS1SMSDS at offset 78(X'4E')
  #
  # Example of listds response:
  #
  # listds 'IBMUSER.LOADLIB' label
  # IBMUSER.LOADLIB
  # --RECFM-LRECL-BLKSIZE-DSORG
  #   U     **    6144    PO                                                                                          
  # --VOLUMES--
  #   VPMVSH
  # --FORMAT 1 DSCB--
  # F1 E5D7D4E5E2C8 0001 780034 000000 09 00 00 C9C2D4D6E2E5E2F24040404040
  # 78003708000000 0200 C0 00 1800 0000 00 0000 82 80000002 000000 0000 0000
  # 0100037D000A037E0004 01010018000C0018000D 0102006F000D006F000E 0000000217
  # --FORMAT 3 DSCB--
  # 03030303 0103009200090092000A 01040092000B0092000C 01050092000D0092000E
  # 0106035B0006035B0007 F3 0107035B0008035B0009 0108035B000A035B000B
  # 00000000000000000000 00000000000000000000 00000000000000000000
  # 00000000000000000000 00000000000000000000 00000000000000000000
  # 00000000000000000000 0000000000
  #
  # SMS flag is in `FORMAT 1 DSCB` section second line, after 780037

  print_trace "- Check if ${ds} is SMS managed"
  ds_label=$(tso_command listds "'${ds}'" label)
  code=$?
  if [ ${code} -eq 0 ]; then
    dscb_fmt1=$(echo "${ds_label}" | sed -e '1,/--FORMAT [18] DSCB--/ d' | sed -e '1,/--/!d' | sed -e '/--.*/ d')
    if [ -z "${dscb_fmt1}" ]; then
      print_error "  * Failed to find format 1 data set control block information."
      return 2
    else
      ds1smsfg=$(echo "${dscb_fmt1}" | head -n 2 | tail -n 1 | sed -e 's#^.\{6\}\(.\{2\}\).*#\1#')
      print_trace "  * DS1SMSFG: ${ds1smsfg}"
      if [ -z "${ds1smsfg}" ]; then
        print_error "  * Failed to find system managed storage indicators from format 1 data set control block."
        return 3
      else
        ds1smsds=$((0x${ds1smsfg} & 0x80))
        print_trace "  * DS1SMSDS: ${ds1smsds}"
        if [ "${ds1smsds}" = "128" ]; then
          # sms managed
          echo "true"
        fi
        return 0
      fi
    fi
  else
    return 1
  fi
}

get_data_set_volume() {
  ds="${1}"

  print_trace "- Find volume of data set ${ds}"
  ds_info=$(tso_command listds "'${ds}'")
  code=$?
  if [ ${code} -eq 0 ]; then
    volume=$(echo "${ds_info}" | sed -e '1,/--VOLUMES--/ d' | sed -e '1,/--/!d' | sed -e '/--.*/ d' | tr -d '[:space:]')
    if [ -z "${volume}" ]; then
      print_error "  * Failed to find volume information of the data set."
      return 2
    else
      echo "${volume}"
      return 0
    fi
  else
    return 1
  fi
}

apf_authorize_data_set() {
  ds="${1}"

  ds_sms_managed=$(is_data_set_sms_managed "${ds}")
  code=$?
  if [ ${code} -ne 0 ]; then
    print_error "Error ZWEL0134E: Failed to find SMS status of data set ${ds}."
    return 134
  fi

  apf_vol_param=
  if [ "${ds_sms_managed}" = "true" ]; then
    print_debug "- ${ds} is SMS managed"
    apf_vol_param="SMS"
  else
    print_debug "- ${ds} is not SMS managed"
    ds_volume=$(get_data_set_volume "${ds}")
    code=$?
    if [ ${code} -eq 0 ]; then
      print_debug "- Volume of ${ds} is ${ds_volume}"
      apf_vol_param="VOLUME=${ds_volume}"
    else
      print_error "Error ZWEL0135E: Failed to find volume of data set ${ds}."
      return 135
    fi
  fi

  apf_cmd="SETPROG APF,ADD,DSNAME=${ds},${apf_vol_param}"
  if [ "${ZWE_CLI_PARAMETER_SECURITY_DRY_RUN}" = "true" ]; then
    print_message "- Dry-run mode, security setup is NOT performed on the system."
    print_message "  Please apply this operator command manually:"
    print_message
    print_message "  ${apf_cmd}"
    print_message
  else
    apf_auth=$(operator_command "${apf_cmd}")
    code=$?
    apf_auth_succeed=$(echo "${apf_auth}" | grep "ADDED TO APF LIST")
    if [ ${code} -eq 0 -a -n "${apf_auth_succeed}" ]; then
      return 0
    else
      print_error "Error ZWEL0136E: Failed to APF authorize data set ${ds}."
      return 136
    fi
  fi
}

create_data_set_tmp_member() {
  ds=${1}
  prefix=${2:-ZW}

  print_trace "  > create_data_set_tmp_member in ${ds}"
  last_rnd=
  idx_retry=0
  max_retry=100
  while true ; do
    if [ ${idx_retry} -gt ${max_retry} ]; then
      print_error "    - Error ZWEL0114E: Reached max retries on allocating random number."
      exit 114
      break
    fi

    rnd=$(echo "${RANDOM}")
    if [ "${rnd}" = "${last_rnd}" ]; then
      # reset random
      RANDOM=$(date '+1%H%M%S')
    fi

    member=$(echo "${prefix}${rnd}" | cut -c1-8)
    print_trace "    - test ${member}"
    member_exist=$(is_data_set_exists "${ds}(${member})")
    print_trace "    - exist? ${member_exist}"
    if [ "${member_exist}" != "true" ]; then
      print_trace "    - good"
      echo "${member}"
      break
    fi

    last_rnd="${rnd}"
    idx_retry=`expr $idx_retry + 1`
  done
}
