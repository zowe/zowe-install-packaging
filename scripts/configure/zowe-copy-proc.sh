#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

#
#  Copy a JCL file from USS to a PROCLIB member
#
echo "<zowe-copy-proc.sh>" >> $LOG_FILE

exitone(){
  tsocmd delete "'$userid.zowetemp.clist' " 1>/dev/null 2>/dev/null
  echo "Unable to create the PROCLIB member " >> $LOG_FILE
  echo "Unable to create the PROCLIB member "   
 
  echo "  "Failed to put ZWESVSTC.JCL in a PROCLIB dataset.
  echo "  "Please add it manually from $ZOWE_ROOT_DIR/ZWESVSTC.JCL to your PROCLIB
  echo "    ""To find PROCLIB datasets, issue /\$D PROCLIB in SDSF"
  echo "</zowe-copy-proc.sh>" >> $LOG_FILE
  exit 1
}
exitzero(){
  tsocmd delete "'$userid.zowetemp.clist' " 1>/dev/null 2>/dev/null
  echo "  "PROC $memberName placed in $proclib
  echo "  PROC $memberName placed in $proclib " >> $LOG_FILE
  echo "</zowe-copy-proc.sh>" >> $LOG_FILE
  exit 0
}

if [[ $# != 3 ]]
then
	echo Usage: copyproc.sh ussfile memberName proclib
	echo ussfile: name of JCL file on USS
	echo memberName: name of member to be written to PROCLIB PDS
  echo proclib: name of PROCLIB PDS, or "auto" for automatic selection
  echo "Not called with 3 parameters: ussfile, memberName, proclib" >> $LOG_FILE
  echo "Called with $# parameters: $@" >> $LOG_FILE
  exitone
fi

ussfile=$1
memberName=$2   # default is set in zowe-parse-yaml.sh
proclib=$3      # default is set in zowe-parse-yaml.sh

# echo "Copying the file" $ussfile "to PROCLIB member" $memberName
ls $ussfile 1>/dev/null 2>/dev/null
if [[ $? > 0 ]]
then
  echo Unable to list $ussfile >> $LOG_FILE
  exitone 
fi
cp $ussfile $ZOWE_ROOT_DIR/ZWESVSTC.JCL
#echo "Preparing CLIST"

# write user's env vars in log
echo LOGNAME=$LOGNAME >> $LOG_FILE
echo USER=$USER >> $LOG_FILE
echo MAIL=$MAIL >> $LOG_FILE
echo HOME=$HOME >> $LOG_FILE
echo whoami=`whoami` >> $LOG_FILE
echo logname=`logname` >> $LOG_FILE


# obtain true TSO userid to create CLIST with
userid=`tsocmd lu 2>/dev/null | sed -n 's/USER=\([^ ]*\) *NAME=.*/\1/p'`

# try to recover in the unlikely event that LISTUSER fails
if [[ "$userid" = "" ]]
then
    echo Unexpected failure to LISTUSER >> $LOG_FILE
    userid=`logname` # the userid they logged in with
    if [[ $? != 0 || "$userid" = "" ]]
    then
        echo "Error - logname command failed to get userid" >> $LOG_FILE
        if [[ "$LOGNAME" = "" ]]
        then
            echo "Warning - LOGNAME not set" >> $LOG_FILE
            if [[ "$USER" = "" ]]
            then
                echo "Warning - USER not set" >> $LOG_FILE
                echo "defaulted to IBMUSER" >> $LOG_FILE
                userid=IBMUSER  # default
            else
                userid=$USER
                echo userid obtained from USER is $userid >> $LOG_FILE
            fi
        else
            userid=$LOGNAME
            echo userid obtained from LOGNAME  is $userid >> $LOG_FILE
        fi
    else
        echo userid obtained from logname  is $userid >> $LOG_FILE
    fi
else
    echo userid obtained from LISTUSER  is $userid >> $LOG_FILE
fi
# end of recovery

echo userid=\[$userid\] >> $LOG_FILE  # brackets to check for trailing blanks

tsocmd delete "'$userid.zowetemp.clist' " 1> $TEMP_DIR/delete.clist.first 2>/dev/null
if [[ $? -ne 0 ]]
then 
  grep -i "ENTRY $userid.zowetemp.clist NOT FOUND" $TEMP_DIR/delete.clist.first > /dev/null
  if [[ $? -ne 0 ]]
  then 
    echo Failed to delete old dataset $userid.zowetemp.clist >> $LOG_FILE
    cat $TEMP_DIR/delete.clist.first  >> $LOG_FILE    
  else 
    echo Old dataset $userid.zowetemp.clist did not exist >> $LOG_FILE
  fi 
else 
  echo Old dataset $userid.zowetemp.clist deleted >> $LOG_FILE
fi 

tsocmd ALLOCATE "DATASET('$userid.zowetemp.clist') NEW SPACE(1) BLOCK(255) LRECL(255)  RECFM(F) DSORG(Po) dsntype(pds) dir(1)" 1>/dev/null 2>/dev/null
if [[ $? > 0 ]]
then
	echo Failed to create new dataset $userid.zowetemp.clist >> $LOG_FILE
  exitone 
fi

# put USS JCL file name in CLIST, because CLIST parms are always uppercased.
sed "s|ussfile|$ussfile|" ${ZOWE_ROOT_DIR}/scripts/internal/ocopyshr.clist > $TEMP_DIR/ocopyshr.e.clist
tsocmd oget "'$TEMP_DIR/ocopyshr.e.clist' '$userid.zowetemp.clist(copyproc)'"  1>/dev/null 2>/dev/null

if [[ $? > 0 ]]
then
	echo Failed to put edited CLIST in $userid.zowetemp.clist >> $LOG_FILE
  exitone
fi
#echo "CLIST copy done, RC $?"

# Process member name
echo Member name $memberName was specified >> $LOG_FILE
# check memberName is valid
# Is member name too long?
if [[ `echo ${memberName} | wc -c` -gt 9 ]]        # 9 includes the string-terminating null character
then 
  echo Member name $memberName longer than 8 characters
  exitone
  # echo Defaulting to ZWESVSTC
  # memberName=ZWESVSTC
fi 
# end of check
echo Member name $memberName was used >> $LOG_FILE

# Process proclib name
echo $proclib | grep -i ^auto$ 1>/dev/null 2>/dev/null  # allow for mixed case
if [[ $? -ne 0 ]]
then
  # auto was not requested
  echo PROCLIB dataset \'$proclib\' was specified >> $LOG_FILE
  # Try the requested PROCLIB
  tsocmd listds \'$proclib\' 1>/dev/null 2>/dev/null
  if [[ $? -ne 0 ]]
  then
    echo "  "Unable to list dataset $proclib >> $LOG_FILE
    tsocmd listds \'$proclib\' 2>> $LOG_FILE 1>> $LOG_FILE # log the error
    exitone 
  else
    echo "    "found PROCLIB dataset $proclib >> $LOG_FILE
      ${ZOWE_ROOT_DIR}/scripts/internal/ocopyshr.sh $proclib $memberName
      if [[ $? > 0 ]]
      then
        echo "  "Unable to write to requested PROCLIB $proclib >> $LOG_FILE
        exitone
      else
        exitzero
      fi
    # done
  fi

else
  echo \'auto\' was requested: choose PROCLIB dataset automatically >> $LOG_FILE
  echo Try JES2 PROCLIB concatenation >> $LOG_FILE
  ${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d t" 1> /dev/null 2> /dev/null  # is 'opercmd' available?
  if [[ $? > 0 ]]
  then
    echo "  "Unable to read JES2 PROCLIB concatenation with opercmd REXX exec >> $LOG_FILE
  else
    procs=`${ZOWE_ROOT_DIR}/scripts/internal/opercmd '$d proclib'|grep DSNAME=.*\.PROCLIB|sed 's/.*DSNAME=\(.*\)\.PROCLIB.*/\1.PROCLIB/'`
    echo "  "procs = $procs >> $LOG_FILE
    for proclib in $procs
    do
      echo "  "proclib = $proclib >> $LOG_FILE
      ${ZOWE_ROOT_DIR}/scripts/internal/ocopyshr.sh $proclib $memberName 
      if [[ $? > 0 ]]
      then
        echo Unable to write to $proclib, try next PROCLIB >> $LOG_FILE
      else
        exitzero
      fi
    done
  fi

  echo Try master JES2 JCL >> $LOG_FILE
  tsocmd oput \'sys1.parmlib\(mstjcl00\)\' \'./mstjcl00\' 1>/dev/null 2>/dev/null
  if [[ $? > 0 ]]
  then
    echo Unable to read master JES2 JCL >> $LOG_FILE
    rm ./mstjcl00
  else
    procs=`grep PROCLIB mstjcl00 | sed 's/.*DSN=\(.*\)\.PROCLIB.*/\1.PROCLIB/'`
    rm ./mstjcl00
    for proclib in $procs
    do
        ${ZOWE_ROOT_DIR}/scripts/internal/ocopyshr.sh $proclib $memberName
        if [[ $? > 0 ]]
        then
          echo Unable to write to $proclib, try another PROCLIB >> $LOG_FILE
        else
          exitzero
        fi
      done
    fi

    echo Try SYS1.PROCLIB >> $LOG_FILE
    proclib=SYS1.PROCLIB
    ${ZOWE_ROOT_DIR}/scripts/internal/ocopyshr.sh $proclib $memberName
    if [[ $? > 0 ]]
    then
      echo Unable to write to SYS1.PROCLIB >> $LOG_FILE
    else
      exitzero
    fi

fi

exitone
