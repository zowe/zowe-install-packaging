#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2019, 2020
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

. ${ZOWE_ROOT_DIR}/bin/utils/setup-log-dir.sh
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

Usage  $SCRIPT -d <dataSetPrefix> [-a <parmlib>] [-r <proclib>]

-d  Data set prefix of source library SZWESAMP, e.g. ${USER}.ZWE.
-a  (optional) DSN of an existing target PARMLIB where the configuration 
    will be placed, e.g. ${USER}.ZWE.CUST.PARMLIB. If ommited then the 
    sample {dataSetPrefix}.SZWESAMP(ZWESIP00) will be used.
-r  (optional) DSN of an existing target PROCLIB where started task JCL 
    will be placed, e.g. USER.PROCLIB. If ommited then the PROCLIB will 
    be selected from the active JES PROCLIB concatenation.
EndOfUsage
script_exit 1
fi

authlib=`echo ${data_set_prefix}.SZWEAUTH | tr '[:lower:]' '[:upper:]'`
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
echo    "samplib =" $samplib >> $LOG_FILE
echo    "parmlib =" $parmlib >> $LOG_FILE
echo    "proclib =" $proclib >> $LOG_FILE

for dsname in $authlib $samplib $parmlib $proclib
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
    script_exit 4
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

# the extra parms ${authlib} ${parmlib} are used to replace DSNs in PROCLIB members
./zowe-copy-to-JES.sh -s ${samplib} -i ${ZWEXASTC} -r ${proclib} -o ${ZWEXASTC} -b ${authlib} -a ${parmlib} -f ${LOG_FILE}
aux_rc=$?
echo "ZWEXASTC rc from zowe-copy-to-JES.sh is ${aux_rc}" >> ${LOG_FILE}
./zowe-copy-to-JES.sh -s ${samplib} -i ${ZWEXMSTC} -r ${proclib} -o ${ZWEXMSTC} -b ${authlib} -a ${parmlib} -f ${LOG_FILE}
xmem_rc=$?
echo "ZWEXMSTC rc from zowe-copy-to-JES.sh is ${xmem_rc}" >> ${LOG_FILE}

if [[ ${xmem_rc} -ne 0 ]]
then
 script_exit ${xmem_rc}
fi
script_exit ${aux_rc}
