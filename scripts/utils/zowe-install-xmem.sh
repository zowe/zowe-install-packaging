#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019, 2020
#######################################################################

# Function: Copy cross-memory server artefacts to the required locations
# ZWE.SZWESAMP:
#
#     ZWESASTC  --> PROCLIB
#     ZWESIP00  --> PARMLIB (optional)
#     ZWESISTC  --> PROCLIB

# Needs ./zowe-copy-to-JES.sh for PROCLIB

while getopts "a:d:l:r:" opt; do
  case $opt in
    a) parmlib=$OPTARG;;
    d) data_set_prefix=$OPTARG;;
    l) LOG_DIRECTORY=$OPTARG;;
    r) proclib=$OPTARG;;
    \?)
      echo "Invalid option: -$opt" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

script_exit(){
  echo exit $1 | tee -a ${LOG_FILE}
  echo "</$SCRIPT>" | tee -a ${LOG_FILE}
  exit $1
}

if [[ -z ${ZOWE_ROOT_DIR} ]]
then
  export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
fi

# identify this script
SCRIPT="$(basename $0)"
# sub-scripts expect the current directory matches their location
cd ${ZOWE_ROOT_DIR}/scripts/utils   

# Source main utils script
. ${ZOWE_ROOT_DIR}/bin/utils/utils.sh

# FIXME: these functions should be added to utils folder and have test cases
#
# Check if data set exists
#
# @param dsn     data set (or with member) name to check
# @return        0: exist
#                1: data set doesn't exist
#                2: data set member doesn't exist
# @output        tso listds label output
ds_exists() {
  cmd="listds '$1' label"
  cmd_output=$(tsocmd "${cmd}" 2>&1)
  cmd_rc=$?
  echo "${cmd_output}"
  if [ "${cmd_rc}" != "0" ]; then
    not_in_catalog=$(echo "${cmd_output}" | grep 'NOT IN CATALOG')
    if [ -n "${not_in_catalog}" ]; then
      return 1
    fi
    member_not_found=$(echo "${cmd_output}" | grep 'MEMBER NAME NOT FOUND')
    if [ -n "${member_not_found}" ]; then
      return 2
    fi
    # some other error we don't know yet
    return 9
  fi

  return 0
}

# List users of a data set
#
# @param dsn     data set name to check
# @return        0: no users
#                1: there are some users
# @output        output of operator command "d grs"
list_ds_user() {
  opercmd=${ZOWE_ROOT_DIR}/scripts/internal/opercmd

  cmd_output=$($opercmd "D GRS,RES=(*,$1)")
  echo "${cmd_output}"
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

  no_requestors=$(echo "${cmd_output}" | grep 'NO REQUESTORS FOR RESOURCE')
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
delete_ds() {
  cmd="delete '$1'"
  cmd_output=$(tsocmd "${cmd}" 2>&1)
  cmd_rc=$?
  echo "${cmd_output}"

  if [ "${cmd_rc}" != "0" ]; then
    not_in_catalog=$(echo "${cmd_output}" | grep 'NOT IN CATALOG')
    if [ -n "${not_in_catalog}" ]; then
      return 1
    fi
    not_found=$(echo "${cmd_output}" | grep 'NOT FOUND')
    if [ -n "${not_found}" ]; then
      return 2
    fi
    in_use=$(echo "${cmd_output}" | grep 'IN USE BY')
    if [ -n "${in_use}" ]; then
      return 3
    fi
    # some other error we don't know yet
    return 9
  fi

  return 0
}

set_install_log_directory ${LOG_DIRECTORY}
validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
set_install_log_file "zowe-install-xmem"

echo "<$SCRIPT>" | tee -a ${LOG_FILE}
echo started from `pwd` >> ${LOG_FILE}

# check parms
missing_parms=
if [[ -z ${data_set_prefix} ]]
then
  missing_parms=${missing_parms}" -d"
fi
#if [[ -z ${parmlib} ]]  # default is SZWESAMP
#then
#  missing_parms=${missing_parms}" -a"
#fi

if [[ -n ${missing_parms} ]]
then
USER=${LOGNAME:-{userid}}
echo Parameters supplied were $@ >> ${LOG_FILE}
echo "Some required parameters were not supplied:${missing_parms}"
cat <<EndOfUsage

Usage  $SCRIPT -d <hlq> [-a <parmlib>] [-r <proclib>] [-l <logDir>]

-d  Data set prefix of source library SZWESAMP, e.g. ${USER}.ZWE.
-a  (optional) DSN of an existing target PARMLIB where the configuration 
    file will be placed, e.g. ${USER}.ZWE.CUST.PARMLIB. If ommited 
    then the sample {dataSetPrefix}.SZWESAMP(ZWESIP00) will be used.
-r  (optional) DSN of an existing target PROCLIB where started task JCL 
    will be placed, e.g. USER.PROCLIB. If ommited then the PROCLIB will 
    be selected from the active JES PROCLIB concatenation.
-l  (optional) Directory where to place the log file. If ommited then
    the log file will be placed in /global/zowe/logs. If it is not 
    writeable then ~/zowe/logs is used as directory.
EndOfUsage
script_exit 1
fi

authlib=`echo ${data_set_prefix}.SZWEAUTH | tr '[:lower:]' '[:upper:]'`
pluglib=`echo ${data_set_prefix}.SZWEPLUG | tr '[:lower:]' '[:upper:]'`
samplib=`echo ${data_set_prefix}.SZWESAMP | tr '[:lower:]' '[:upper:]'`

if [[ -z ${parmlib} ]]
then
  parmlib=$samplib
else
  parmlib=`echo ${parmlib} | tr '[:lower:]' '[:upper:]'`
fi


if [[ -z ${proclib} ]]
then
  proclib=auto
else
  proclib=`echo ${proclib} | tr '[:lower:]' '[:upper:]'`
fi

echo    "authlib =" $authlib >> $LOG_FILE
echo    "pluglib =" $pluglib >> $LOG_FILE
echo    "samplib =" $samplib >> $LOG_FILE
echo    "parmlib =" $parmlib >> $LOG_FILE
echo    "proclib =" $proclib >> $LOG_FILE

for dsname in $authlib $samplib $parmlib $proclib $pluglib
do
  if [[ $proclib = auto ]]
  then
    continue  # do not check DSN=auto
  fi

  if [[ `echo $dsname | wc -c` -gt 44+1 ]] # character count includes trailing newline
  then
    echo Specified dataset name $dsname is too long | tee -a ${LOG_FILE}
    script_exit 3
  fi

  tsocmd listds "'$dsname'" 1>> $LOG_FILE 2>> $LOG_FILE
  if [[ $? -ne 0 ]]
  then
    echo Dataset \"$dsname\" not found | tee -a ${LOG_FILE}
    if [[ $dsname = $pluglib ]]
    then
      echo If ZIS plugin library desired, create \"$pluglib\" before installing ZIS plugins
    else
      script_exit 4
    fi
  fi
done

# PARMLIB  - - - - - - - - - - - - - - - -
# parmlib       {hlq}.ZIS.PARMLIB       DSN of target PARMLIB where member ZWEXMP00 goes
# The suffix (last 2 digits) can be adjusted in the STC JCL, but the prefix must be ZWESIP
ZWEXMP00=ZWESIP00  # for ZWESIS01
  tsocmd listds "'$samplib' members" 2>> $LOG_FILE | grep "  $ZWEXMP00$" 1>> $LOG_FILE 2>> $LOG_FILE
  if [[ $? -ne 0 ]]
  then
    echo $ZWEXMP00 not found in \"$samplib\" | tee -a ${LOG_FILE}
    script_exit 7
  fi

  if [[ $samplib = $parmlib ]]
  then
    echo "Using SAMPLIB member ${samplib}(${ZWEXMP00})" | tee -a ${LOG_FILE}
  else
    # check if parmlib member exists
    cmd_output=$(ds_exists "${parmlib}(${ZWEXMP00})")
    cmd_rc=$?
    if [ "${cmd_rc}" = "0" ]; then
      # already exist, try to delete
      echo "SAMPLIB member ${ZWEXMP00} already exists, try to delete before overwrite" | tee -a ${LOG_FILE}
      cmd_output=$(delete_ds "${parmlib}(${ZWEXMP00})")
      cmd_rc=$?
      if [ "${cmd_rc}" = "3" ]; then
        # data set in use
        echo "Error:  PARMLIB ${parmlib} member ${ZWEXMP00} is in-use, cannot overwrite" | tee -a ${LOG_FILE}
        echo "Check if PARMLIB dataset ${parmlib} is in use by xmem server or another job or user" | tee -a ${LOG_FILE}
        echo "TSO delete command output:\n${cmd_output}" | tee -a ${LOG_FILE}
        script_exit 8
      elif [ "${cmd_rc}" != "0" ]; then
        echo "Warning:  delete PARMLIB ${parmlib} member ${ZWEXMP00} failed with code ${cmd_rc}" | tee -a ${LOG_FILE}
        echo "TSO delete command output:\n${cmd_output}" | tee -a ${LOG_FILE}
        echo "Will proceed and see if we can overwrite it" | tee -a ${LOG_FILE}
      fi
    else
      echo "PARMLIB ${parmlib} member ${ZWEXMP00} doesn't exist" | tee -a ${LOG_FILE}
    fi

    echo "Copying SAMPLIB member ${ZWEXMP00}" | tee -a ${LOG_FILE}
    if cp "//'${samplib}(${ZWEXMP00})'"  "//'${parmlib}(${ZWEXMP00})'"
    then
      echo "Info:  member ${ZWEXMP00} has been successfully copied to dataset ${parmlib}" | tee -a ${LOG_FILE}
      # rc=0
    else
      echo "Error:  member ${ZWEXMP00} has not been copied to dataset ${parmlib}" | tee -a ${LOG_FILE}
      echo "Check if PARMLIB dataset ${parmlib} is in use by xmem server or another job or user" | tee -a ${LOG_FILE}
      script_exit 8
    fi
  fi

# PROCLIB  - - - - - - - - - - - - - - - -
ZWEXASTC=ZWESASTC  # for ZWESAUX
ZWEXMSTC=ZWESISTC  # for ZWESIS01

# the extra parms ${authlib} ${parmlib} ${pluglib} are used to replace DSNs in PROCLIB members
./zowe-copy-to-JES.sh \
  -s ${samplib} \
  -i ${ZWEXASTC} \
  -r ${proclib} \
  -o ${ZWEXASTC} \
  -b ${authlib} \
  -a ${parmlib} \
  -p ${pluglib} \
  -f ${LOG_FILE}
aux_rc=$?
echo "ZWEXASTC rc from zowe-copy-to-JES.sh is ${aux_rc}" >> ${LOG_FILE}
./zowe-copy-to-JES.sh \
  -s ${samplib} \
  -i ${ZWEXMSTC} \
  -r ${proclib} \
  -o ${ZWEXMSTC} \
  -b ${authlib} \
  -a ${parmlib} \
  -p ${pluglib} \
  -f ${LOG_FILE}
xmem_rc=$?
echo "ZWEXMSTC rc from zowe-copy-to-JES.sh is ${xmem_rc}" >> ${LOG_FILE}

if [[ ${xmem_rc} -ne 0 ]]
then
 script_exit ${xmem_rc}
fi
script_exit ${aux_rc}
