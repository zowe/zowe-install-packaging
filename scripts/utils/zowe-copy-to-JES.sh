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

# Function: Copy SAMPLIB member into JES PROCLIB concatenation
# Usage:  ./zowe-copy-to-JES.sh $samplib $Imember $proclib $Omember

# Needs ../internal/opercmd to check JES concatenation
# Needs ./mcopyshr.clist to write to the target PDS

# Creates/deletes 2 temporary datasets
#   $userid.zowetemp.instproc.SZWESAMP.proclib
#   $userid.zowetemp.instproc.SZWESAMP.clist 
# Creates log file in user's home directory

# Edits members during copy
# sed -e "s/${XMEM_ELEMENT_ID}.SISLOAD/${XMEM_LOADLIB}/g" \
#     -e "s/${XMEM_ELEMENT_ID}.SISSAMP/${XMEM_PARMLIB}/g" \
#     -e "s/NAME='ZWESIS_STD'/NAME='${XMEM_SERVER_NAME}'/g" \
#     ${ZSS}/SAMPLIB/ZWESIS01 > ${ZSS}/SAMPLIB/${XMEM_JCL}.tmp
# sed -e "s/zis-loadlib/${XMEM_LOADLIB}/g" \
#     ${ZSS}/SAMPLIB/ZWESAUX > ${ZSS}/SAMPLIB/${XMEM_AUX_JCL}.tmp


script_exit(){
  tsocmd delete "'$clist'"   1>> $LOG_FILE 2>> $LOG_FILE
  tsocmd delete "'$templib'" 1>> $LOG_FILE 2>> $LOG_FILE
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

# code starts here

samplib=$1
Imember=$2
proclib=$3
Omember=$4
loadlib=$5
parmlib=$6

userid=${USER:-${USERNAME:-${LOGNAME}}}
templib=$userid.zowetemp.instproc.SZWESAMP.proclib
clist=$userid.zowetemp.instproc.SZWESAMP.clist 

echo    "userid  =" $userid  >> $LOG_FILE
echo    "templib =" $templib >> $LOG_FILE
echo    "clist   =" $clist   >> $LOG_FILE

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
  script_exit 2
fi

# put member MCOPYSHR in CLIST
tsocmd oget "'./mcopyshr.clist' '$clist(mcopyshr)'"  1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
	echo Failed to put member MCOPYSHR in CLIST $clist | tee -a ${LOG_FILE}
  script_exit 3
fi
tsocmd listds "'$clist' members" 1>> $LOG_FILE 2>> $LOG_FILE

# create temp PROCLIB PDS
tsocmd delete "'$templib'" 1>> $LOG_FILE 2>> $LOG_FILE
tsocmd ALLOCATE "DATASET('$templib') NEW SPACE(1) BLOCK(3120) LRECL(80)  RECFM(F b) DSORG(Po) dsntype(pds) dir(1)" 1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
	echo Failed to create new CLIST PDS $clist | tee -a ${LOG_FILE}
  script_exit 4
fi

tsocmd listds "'$samplib'" 1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
  echo Dataset \"$samplib\" not found | tee -a ${LOG_FILE}
  script_exit 5
fi

tsocmd listds "'$samplib' members" 2>> $LOG_FILE | grep -i "  $Imember$" 1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
  echo $Imember not found in \"$samplib\" | tee -a ${LOG_FILE}
  script_exit 6
fi

echo Check name of $Imember PROC | tee -a ${LOG_FILE}
cat "//'$samplib($Imember)'" | grep -i "^//$Imember *PROC " 1>> $LOG_FILE 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
  echo Did not find \"//$Imember\" in "$samplib($Imember)" | tee -a ${LOG_FILE}
  echo PROC statement is : | tee -a ${LOG_FILE}
  cat "//'$samplib($Imember)'" | grep "^//.* PROC " | tee -a ${LOG_FILE}
fi

# We used to perform a straight copy ...
#    cp "//'$samplib($Imember)'" "//'$templib($Imember)'"
# But now we edit the JCL in flight ...
sed -e "s/ZWES.SISLOAD/${loadlib}/g" \
    -e "s/ZWES.SISSAMP/${samplib}/g" \
    -e "s/zis-loadlib/${loadlib}/g" \
    "//'$samplib($Imember)'" > /tmp/$samplib.$Imember.jcl
if [[ $? -ne 0 ]]
then
	echo Failed to edit "//'$samplib($Imember)'" into /tmp/$samplib.$Imember.jcl | tee -a ${LOG_FILE}
  script_exit 8
else
  echo Edited "//'$samplib($Imember)'" 
fi
cp /tmp/$samplib.$Imember.jcl "//'$templib($Imember)'"
if [[ $? -ne 0 ]]
then
	echo Failed to copy /tmp/$samplib.$Imember.jcl into "$templib($Imember)" | tee -a ${LOG_FILE}
  script_exit 8
else
  echo Copied into "//'$templib($Imember)'"   
fi

if [[ $proclib = auto ]]
then
    if [[ ! -x ../internal/opercmd ]]
    then
      echo Unable to execute ../internal/opercmd | tee -a ${LOG_FILE}
      script_exit 9
    fi
    
    # Check we can display PROCLIB
    ../internal/opercmd '$d proclib' | grep \$HASP319 >> $LOG_FILE
    if [[ $? -ne 0 ]]
    then
      echo Unable to display PROCLIBs | tee -a ${LOG_FILE}
      script_exit 10
    fi 

    # Obtain list of PROCLIBs in JES concatenation
    procs=`../internal/opercmd '$d proclib' | sed -n 's/.*DSNAME=\([^,^)^ ]*\).*/\1/p' | sort | uniq `
    echo "  "Candidate PROCLIBs = $procs >> $LOG_FILE
    for candidate in $procs
    do
      echo "  " candidate = $candidate >> $LOG_FILE
      tsocmd "exec '$clist(mcopyshr)' '$templib($Imember) $candidate($Omember)'" 1>> $LOG_FILE 2>> $LOG_FILE
 
      if [[ $? -ne 0 ]]
      then
        echo Unable to write $Omember to PROCLIB dataset $candidate, try next PROCLIB >> $LOG_FILE
      else
        echo "$samplib($Imember) was written to $candidate($Omember)" | tee -a ${LOG_FILE}
        tsocmd listds "'$candidate' members" 1>> $LOG_FILE 2>> $LOG_FILE
        script_exit 0
      fi
    done
    echo "$Imember was not written to any JES PROCLIB dataset" | tee -a ${LOG_FILE}
    script_exit 11
else
  tsocmd listds "'$proclib' " 1>> $LOG_FILE 2>> $LOG_FILE
  if [[ $? -ne 0 ]]
  then
    echo Unable to list target PROCLIB dataset $proclib | tee -a ${LOG_FILE}
    script_exit 12
  fi 

  tsocmd "exec '$clist(mcopyshr)' '$templib($Imember) $proclib($Omember)'" 1>> $LOG_FILE 2>> $LOG_FILE
  if [[ $? -ne 0 ]]
  then
    echo Unable to write to PROCLIB dataset $proclib | tee -a ${LOG_FILE}
    script_exit 13
  else
    echo "$Imember was written to $proclib($Omember)" | tee -a ${LOG_FILE}
    tsocmd listds "'$proclib' members" 1>> $LOG_FILE 2>> $LOG_FILE
    script_exit 0
  fi

fi
