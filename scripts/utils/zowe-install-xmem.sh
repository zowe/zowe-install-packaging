#!/bin/sh
################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019, 2020
################################################################################

# Function: Copy cross-memory server artefacts to the required locations
# ZWE.SZWEAUTH:
#
#     ZWESAUX   --> LOADLIB
#     ZWESIS01  --> LOADLIB
#
# ZWE.SZWESAMP:
#
#     ZWESASTC  --> PROCLIB
#     ZWESIP00  --> PARMLIB
#     ZWESISTC  --> PROCLIB

# Needs ./zowe-copy-to-JES.sh for PROCLIB

# zip #1157 - blocked by # zip #1156
# while getopts "l:" opt; do
#   case $opt in
#     l) LOG_DIRECTORY=$OPTARG;;
#     \?)
#       echo "Invalid option: -$opt" >&2
#       exit 1
#       ;;
#   esac
# done
# shift $(($OPTIND-1))

script_exit(){
  echo exit $1 | tee -a ${LOG_FILE}
  echo "</$SCRIPT>" | tee -a ${LOG_FILE}
  exit $1
}
# identify this script
SCRIPT="$(basename $0)"

# If log directory not specified on input default to home
if [[ -z "${LOG_DIRECTORY}" ]]
then
  LOG_DIRECTORY=${HOME}
fi
mkdir -p ${LOG_DIRECTORY}

LOG_FILE=${LOG_DIRECTORY}/${SCRIPT}-`date +%Y-%m-%d-%H-%M-%S`.log
touch $LOG_FILE
chmod a+rw $LOG_FILE

echo "<$SCRIPT>" | tee -a ${LOG_FILE}
echo started from `pwd` >> ${LOG_FILE}

# check parms
if [[ $# -lt 3 || $# -gt 4 ]]
then
echo Expected 3 or 4 parameters, found $# | tee -a ${LOG_FILE}
echo Parameters supplied were $@ | tee -a ${LOG_FILE}
echo Usage:
cat <<EndOfUsage
  $SCRIPT datasetPrefix loadlib parmlib proclib

    Parameter subsitutions:
    Parm name     Value e.g.              Meaning
    ---------     ----------              -------
 1  datasetPrefix {userid}.ZWE            Dataset prefix of source library .SZWEAUTH where members ZWESIS01,ZWESAUX are located
                                          and of source library .SZWESAMP where members ZWESASTC, ZWESIP00 and ZWESISTC are located.
 2  loadlib       {hlq}.ZIS.SZISLOAD      DSN of target LOADLIB where members ZWESIS01,ZWESAUX will be placed. 
                  
 3  parmlib       {hlq}.ZIS.PARMLIB       DSN of target PARMLIB where member ZWESIP00 will be placed. 
 
 4  proclib       USER.PROCLIB            DSN of target PROCLIB where members ZWESASTC and ZWESISTC will be placed. 
                  (omitted)               PROCLIB will be selected from JES PROCLIB concatenation.

EndOfUsage
script_exit 1
fi

authlib=`echo $1.SZWEAUTH | tr '[:lower:]' '[:upper:]'`
loadlib=`echo $2 | tr '[:lower:]' '[:upper:]'`
samplib=`echo $1.SZWESAMP | tr '[:lower:]' '[:upper:]'`
parmlib=`echo $3 | tr '[:lower:]' '[:upper:]'`
 
if [[ $# -eq 4 ]]
then
  proclib=`echo $4 | tr '[:lower:]' '[:upper:]'`
else
  proclib=auto
fi 

echo    "authlib =" $authlib >> $LOG_FILE
echo    "loadlib =" $loadlib >> $LOG_FILE
echo    "samplib =" $samplib >> $LOG_FILE
echo    "parmlib =" $parmlib >> $LOG_FILE
echo    "proclib =" $proclib >> $LOG_FILE

for dsname in $authlib $loadlib $samplib $parmlib $proclib
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

# AUTHLIB  - - - - - - - - - - - - - - - - 
ZWESAUX=ZWESAUX
ZWESIS01=ZWESIS01

for loadmodule in $ZWESAUX $ZWESIS01
do 

  tsocmd listds "'$authlib' members" 2>> $LOG_FILE | grep "  $loadmodule$" 1>> $LOG_FILE 2>> $LOG_FILE
  if [[ $? -ne 0 ]]
  then
    echo $loadmodule not found in \"$authlib\" | tee -a ${LOG_FILE}
    script_exit 5
  fi

  echo "Copying load module ${loadmodule}" | tee -a ${LOG_FILE}
  if cp -X "//'${authlib}(${loadmodule})'"  "//'${loadlib}(${loadmodule})'" 
  then
    echo "Info:  module ${loadmodule} has been successfully copied to dataset ${loadlib}" | tee -a ${LOG_FILE}
    rc=0
  else
    echo "Error:  module ${loadmodule} has not been copied to dataset ${loadlib}" | tee -a ${LOG_FILE}
    script_exit 6
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

# PROCLIB  - - - - - - - - - - - - - - - - 
ZWEXASTC=ZWESASTC  # for ZWESAUX
ZWEXMSTC=ZWESISTC  # for ZWESIS01

# the extra parms ${loadlib} ${parmlib} are used to replace DSNs in PROCLIB members
./zowe-copy-to-JES.sh -s ${samplib} -i ${ZWEXASTC} -r ${proclib} -o ${ZWEXASTC} -d ${loadlib} -a ${parmlib} -l ${LOG_DIRECTORY}
./zowe-copy-to-JES.sh -s ${samplib} -i ${ZWEXMSTC} -r ${proclib} -o ${ZWEXMSTC} -d ${loadlib} -a ${parmlib} -l ${LOG_DIRECTORY}

script_exit 0
