#!/bin/sh
################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019, 2019
################################################################################

# Function: Copy datasetPrefx.SZWESAMP(member) to JES concatenation
# Needs ./zowe-copy-to-JES.sh
script_exit(){
  echo exit $1 | tee -a ${LOG_FILE}
  echo "</$SCRIPT>" | tee -a ${LOG_FILE}
  exit $1
}
# identify this script
SCRIPT="$(basename $0)"

LOG_FILE=~/${SCRIPT}-`date +%Y-%m-%d-%H-%M-%S`.log
touch $LOG_FILE
chmod a+rw $LOG_FILE

echo "<$SCRIPT>" | tee -a ${LOG_FILE}
echo started from `pwd` >> ${LOG_FILE}

# check parms
if [[ $# -lt 1 || $# -gt 2 ]]
then
echo Expected 1 or 2 parameters, found $# | tee -a ${LOG_FILE}
echo Parameters supplied were $@ | tee -a ${LOG_FILE}
echo Usage:
cat <<EndOfUsage
  $SCRIPT Imember proclib [Omember]

    Parameter subsitutions:
    Parm name     Value e.g.              Meaning
    ---------     ----------              -------
 1  datasetPrefix {userid}.ZWE            Dataset prefix of source library .SZWESAMP where member ZWESVSTC is located.

 2  proclib       USER.PROCLIB            DSN of target PROCLIB where member ZWESVSTC will be placed. 
                  (omitted)               PROCLIB will be selected from JES PROCLIB concatenation.
EndOfUsage
script_exit 1
fi

# check invocation path
dirName=$(dirname `pwd`)
parentDir=$(basename $dirName)
baseDir=$(basename `pwd`)

if [[ $baseDir != utils || $parentDir != scripts ]]
then
  echo Wrong directory `pwd`, you must be in scripts/utils to run this script | tee -a ${LOG_FILE}
  script_exit 2
fi 

samplib=$1.SZWESAMP
if [[ $# -eq 2 ]]
then
  proclib=$2
else
  proclib=auto
fi

Imember=ZWESVSTC
Omember=ZWESVSTC

echo    "samplib =" $samplib >> $LOG_FILE
echo    "proclib =" $proclib >> $LOG_FILE

for dsname in $samplib $proclib
do
  if [[ `echo $dsname | wc -c` -gt 44+1 ]] # character count includes trailing newline
  then
    echo Specified dataset name $dsname is too long | tee -a ${LOG_FILE}
    script_exit 3
  fi
done

./zowe-copy-to-JES.sh $samplib $Imember $proclib $Omember

script_exit 0
