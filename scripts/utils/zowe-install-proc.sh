#!/bin/sh
################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019, 2021
################################################################################

# Function: Copy Zowe server PROC from datasetPrefx.SZWESAMP(ZWESVSTC) to JES concatenation
# Needs ./zowe-copy-to-JES.sh

while getopts "d:l:r:" opt; do
  case $opt in
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
  echo exit $1 >> ${LOG_FILE}
  echo "</$SCRIPT>" >> ${LOG_FILE}
  exit $1
}

if [[ -z ${ZOWE_ROOT_DIR} ]]
then
  export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
fi

# identify this script
SCRIPT="$(basename $0)"

# Source main utils script
. ${ZOWE_ROOT_DIR}/bin/utils/utils.sh

set_install_log_directory ${LOG_DIRECTORY}
validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
set_install_log_file "zowe-install-proc"

echo "<$SCRIPT>" >> ${LOG_FILE}
echo started from `pwd` >> ${LOG_FILE}

if [[ -z ${data_set_prefix} ]]
then
echo Parameters supplied were $@ >> ${LOG_FILE}
echo "-d parameter not set"
cat <<EndOfUsage
Usage $SCRIPT -d <dataSetPrefix> [-r <proclib>]
Opt flag    Parm name     Value e.g.              Meaning
--------    ---------     ----------              -------
   -d       dataSetPrefix {userid}.ZWE            Data set prefix of source library .SZWESAMP where member ZWESVSTC is located.

   -r       proclib       USER.PROCLIB            DSN of target PROCLIB where member ZWESVSTC will be placed. 
                          (omitted)               PROCLIB will be selected from JES PROCLIB concatenation.
EndOfUsage
script_exit 1
fi

if [[ -z ${proclib} ]]
then
proclib=auto
fi

samplib=${data_set_prefix}.SZWESAMP
members_to_copy="ZWESVSTC ZWESLSTC"

echo    "samplib =" ${samplib} >> $LOG_FILE
echo    "proclib =" ${proclib} >> $LOG_FILE

for dsname in ${samplib} ${proclib}
do
  if [[ `echo ${dsname} | wc -c` -gt 44+1 ]] # character count includes trailing newline
  then
    echo Specified dataset name ${dsname} is too long | tee -a ${LOG_FILE}
    script_exit 3
  fi
done

rc=0

for member in $members_to_copy
do 
  ./zowe-copy-to-JES.sh -s ${samplib} -i ${member} -r ${proclib} -o ${member} -f ${LOG_FILE}
  rc=$?
  if [[ ${rc} -ne 0 ]]
  then
    echo "rc from zowe-copy-to-JES.sh is ${rc}" >> ${LOG_FILE}
    script_exit ${rc}
  fi
done
echo "rc from zowe-copy-to-JES.sh is ${rc}" >> ${LOG_FILE}
script_exit ${rc}