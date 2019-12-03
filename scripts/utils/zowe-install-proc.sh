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

# Function: Copy datasetPrefx.SZWESAMP(ZWESVSTC) to JES concatenation

# Needs $ZOWE_ROOT_DIR/scripts/configure/zowe-install.yaml to obtain datasetPrefix
# Needs ../internal/opercmd to check JES concatenation
# Needs ./mcopyshr.clist to write to the target PDS

# Creates/deletes 2 temporary datasets
#   $userid.zowetemp.instproc.SZWESAMP.proclib
#   $userid.zowetemp.instproc.SZWESAMP.clist 
# Creates log file in user's home directory

# You must be in $ZOWE_ROOT_DIR/scripts/utils to run this script,
# which is how it determines the value of $ZOWE_ROOT_DIR

# Usage:  $SCRIPT proclib member
# ... see usage message below for details

script_exit(){
  tsocmd delete "'$clist'"   1>> $LOG_FILE 2>> $LOG_FILE
  tsocmd delete "'$templib'" 1>> $LOG_FILE 2>> $LOG_FILE
  rm ~/$templib.ZWESVSTC.$$.jcl 1>> $LOG_FILE 2>> $LOG_FILE
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

userid=${USER:-${USERNAME:-${LOGNAME}}}
templib=$userid.zowetemp.instproc.SZWESAMP.proclib
clist=$userid.zowetemp.instproc.SZWESAMP.clist 

# check parms
if [[ $# -lt 1 || $# -gt 2 ]]
then
echo Expected 1 or 2 parameters, found $# | tee -a ${LOG_FILE}
echo Parameters supplied were $@ | tee -a ${LOG_FILE}
echo Usage:
cat <<EndOfUsage
  $SCRIPT proclib member

   Parameter subsitutions:
   Parm name      Value         Meaning
   ---------      ----------    -------
 1  proclib       USER.PROCLIB  DSN of target PROCLIB where member will be placed 
                  auto          PROCLIB will be selected from JES PROCLIB concatenation.  'auto' must be lowercase
 2  member        ZWESVSTC      member name of Zowe server JCL PROC
                  (omitted)     if omitted, defaults to ZWESVSTC
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
  script_exit 1
fi 

proclib=${1}
if [[ $# -eq 2 ]]
then
  procmem=$2
else
  procmem=ZWESVSTC
fi

echo    "proclib =" $proclib >> $LOG_FILE
echo    "member  =" $procmem >> $LOG_FILE
echo    "userid  =" $userid  >> $LOG_FILE
echo    "templib =" $templib >> $LOG_FILE
echo    "clist   =" $clist   >> $LOG_FILE

if [[ `echo $procmem | wc -c` -gt 8+1 ]] # character count includes trailing newline
then
  echo Specified member name $procmem is too long | tee -a ${LOG_FILE}
  script_exit 1
fi

if [[ `echo $proclib | wc -c` -gt 44+1 ]] # character count includes trailing newline
then
  echo Specified PROCLIB dataset name $proclib is too long | tee -a ${LOG_FILE}
  script_exit 1
fi

# create temp CLIST PDS
tsocmd delete "'$clist'" 1>> $LOG_FILE 2>> $LOG_FILE
tsocmd ALLOCATE "DATASET('$clist') NEW SPACE(1) BLOCK(255) LRECL(255)  RECFM(F) DSORG(Po) dsntype(pds) dir(1)" 1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
	echo Failed to create new CLIST PDS $clist | tee -a ${LOG_FILE}
  script_exit 1
fi

if [[ ! -x ./mcopyshr.clist ]]
then
	echo File ./mcopyshr.clist missing or not executable | tee -a ${LOG_FILE}
  script_exit 1
fi

# put member MCOPYSHR in CLIST
tsocmd oget "'./mcopyshr.clist' '$clist(mcopyshr)'"  1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
	echo Failed to put member MCOPYSHR in CLIST $clist | tee -a ${LOG_FILE}
  script_exit 1
fi
tsocmd listds "'$clist' members" 1>> $LOG_FILE 2>> $LOG_FILE

# create temp PROCLIB PDS
tsocmd delete "'$templib'" 1>> $LOG_FILE 2>> $LOG_FILE
tsocmd ALLOCATE "DATASET('$templib') NEW SPACE(1) BLOCK(3120) LRECL(80)  RECFM(F b) DSORG(Po) dsntype(pds) dir(1)" 1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
	echo Failed to create new CLIST PDS $clist | tee -a ${LOG_FILE}
  script_exit 1
fi

# check ${ZOWE_ROOT_DIR}/scripts/configure/zowe-install.yaml
if [[ ! -r ../configure/zowe-install.yaml ]]
then
  echo Unable to read ../configure/zowe-install.yaml | tee -a ${LOG_FILE}
  script_exit 1
fi

echo Scanning yaml file for datasetPrefix: >> $LOG_FILE
grep "^ *datasetPrefix=" ../configure/zowe-install.yaml 1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
  echo Entry \"datasetPrefix\" not found in ../configure/zowe-install.yaml | tee -a ${LOG_FILE}
  script_exit 1
fi

ZOWE_DSN_PREFIX=`grep "^ *datasetPrefix=" ../configure/zowe-install.yaml | sed "s/{userid}/$userid/" | sed "s/^ *datasetPrefix=\([^ ]*\) */\1/"`
echo Edited datasetPrefix: >> $LOG_FILE
if [[ -n "${ZOWE_DSN_PREFIX}" ]]
then
  echo datasetPrefix = ${ZOWE_DSN_PREFIX} 1>> $LOG_FILE 2>> $LOG_FILE
else 
  echo datasetPrefix is blank | tee -a ${LOG_FILE}
  script_exit 1
fi

tsocmd listds "'${ZOWE_DSN_PREFIX}.SZWESAMP'" 1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
  echo Dataset \"${ZOWE_DSN_PREFIX}.SZWESAMP\" not found | tee -a ${LOG_FILE}
  script_exit 1
fi

tsocmd listds "'${ZOWE_DSN_PREFIX}.SZWESAMP' members" 2>> $LOG_FILE | grep "  ZWESVSTC$" 1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
  echo ZWESVSTC not found in \"${ZOWE_DSN_PREFIX}.SZWESAMP\" | tee -a ${LOG_FILE}
  script_exit 1
fi

echo Check name of ZWESVSTC PROC >> $LOG_FILE
cat "//'${ZOWE_DSN_PREFIX}.SZWESAMP(ZWESVSTC)'" | grep //ZWESVSTC 1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
  echo Did not find \"//ZWESVSTC\" in "${ZOWE_DSN_PREFIX}.SZWESAMP(ZWESVSTC)" | tee -a ${LOG_FILE}
  script_exit 1
fi

cp ~/$templib.ZWESVSTC.$$.jcl "//'$templib(ZWESVSTC)'"
if [[ $? -ne 0 ]]
then
	echo Failed to copy ~/$templib.ZWESVSTC.$$.jcl into "$templib(ZWESVSTC)" | tee -a ${LOG_FILE}
  script_exit 1
fi

if [[ $proclib = auto ]]
then
    if [[ ! -x ../internal/opercmd ]]
    then
      echo Unable to execute ../internal/opercmd | tee -a ${LOG_FILE}
      script_exit 1
    fi
    
    # Check we can display PROCLIB
    ../internal/opercmd '$d proclib' | grep \$HASP319 >> $LOG_FILE
    if [[ $? -ne 0 ]]
    then
      echo Unable to display PROCLIBs | tee -a ${LOG_FILE}
      script_exit 1
    fi 

    procs=`../internal/opercmd '$d proclib'|grep DSNAME=.*\,|sed 's/.*DSNAME=\(.*\)\,.*/\1/'`
    echo "  "Candidate PROCLIBs = $procs >> $LOG_FILE
    for candidate in $procs
    do
      echo "  " candidate = $candidate >> $LOG_FILE
      tsocmd "exec '$clist(mcopyshr)' '$templib(ZWESVSTC) $candidate($procmem)'" 1>> $LOG_FILE 2>> $LOG_FILE
 
      if [[ $? -ne 0 ]]
      then
        echo Unable to write $procmem to PROCLIB dataset $candidate, try next PROCLIB >> $LOG_FILE
      else
        echo "ZWESVSTC was written to $candidate($procmem)" | tee -a ${LOG_FILE}
        tsocmd listds "'$candidate' members" 1>> $LOG_FILE 2>> $LOG_FILE
        script_exit 0
      fi
    done
    echo "ZWESVSTC was not written to any JES PROCLIB dataset" | tee -a ${LOG_FILE}
    script_exit 1
else
  tsocmd listds "'$proclib' " 1>> $LOG_FILE 2>> $LOG_FILE
  if [[ $? -ne 0 ]]
  then
    echo Unable to list target PROCLIB dataset $proclib | tee -a ${LOG_FILE}
    script_exit 1
  fi 

  tsocmd "exec '$clist(mcopyshr)' '$templib(ZWESVSTC) $proclib($procmem)'" 1>> $LOG_FILE 2>> $LOG_FILE
  if [[ $? -ne 0 ]]
  then
    echo Unable to write to PROCLIB dataset $proclib | tee -a ${LOG_FILE}
    script_exit 1
  else
    echo "ZWESVSTC was written to $proclib($procmem)" | tee -a ${LOG_FILE}
    tsocmd listds "'$proclib' members" 1>> $LOG_FILE 2>> $LOG_FILE
    script_exit 0
  fi

fi
