#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

#
#  Copy a JCL file from USS to a PROCLIB member
#
echo "<zowe-copy-proc.sh>" >> $LOG_FILE

exitone(){
  echo "</zowe-copy-proc.sh>" >> $LOG_FILE
  exit 1
}
exitzero(){
  echo "</zowe-copy-proc.sh>" >> $LOG_FILE
  exit 0
}

if [[ $# != 2 ]]
then
	echo Usage: copyproc.sh ussfile membername
	echo ussfile: name of JCL file on USS
	echo membername: name of member to be written to PROCLIB PDS
  echo "Not called with two parameters for required ussfile , membername" >> $LOG_FILE
  exitone
fi

ussfile=$1
membername=$2

if [[ `basename $ussfile` == $ussfile ]] # add pathname if not present
then
	ussfile=`pwd`/$ussfile
fi

# echo "Copying the file" $ussfile "to PROCLIB member" $membername
ls $ussfile 1>/dev/null 2>/dev/null
if [[ $? > 0 ]]
then
  echo Unable to list $ussfile
  exit 1
fi
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
echo userid from LISTUSER=$userid >> $LOG_FILE

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
                echo userid obtained from USER >> $LOG_FILE
            fi
        else
            userid=$LOGNAME
            echo userid obtained from LOGNAME >> $LOG_FILE
        fi
    else
        echo userid obtained from logname >> $LOG_FILE
    fi
else
    echo userid obtained from LISTUSER >> $LOG_FILE
fi
# end of recovery

echo userid=\[$userid\] >> $LOG_FILE  # brackets to check for trailing blanks

tsocmd delete "'$userid.zowetemp.clist' " 1>/dev/null 2>/dev/null

tsocmd ALLOCATE "DATASET('$userid.zowetemp.clist') NEW SPACE(1) BLOCK(255) LRECL(255)  RECFM(F) DSORG(Po) dsntype(pds) dir(1)" 1>/dev/null 2>/dev/null
if [[ $? > 0 ]]
then
	echo Failed to create new dataset $userid.zowetemp.clist >> $LOG_FILE
fi

# put USS JCL file name in CLIST, because CLIST parms are always uppercased.
cd $INSTALL_DIR/scripts
sed "s|ussfile|$ussfile|" ocopyshr.clist > $TEMP_DIR/ocopyshr.e.clist
tsocmd oget "'$TEMP_DIR/ocopyshr.e.clist' '$userid.zowetemp.clist(copyproc)'"  1>/dev/null 2>/dev/null

if [[ $? > 0 ]]
then
	echo Failed to put edited CLIST in $userid.zowetemp.clist >> $LOG_FILE
fi
#echo "CLIST copy done, RC $?"

# echo Try USER.*.PROCLIB
procs=`tsocmd listds \'user.\*.proclib\'` 1>/dev/null 2>/dev/null
if [[ $? > 0 ]]
then
  echo "  "Unable to find any USER.*.PROCLIB >> $LOG_FILE
else
  procs=`tsocmd listds \'user.\*.proclib\' 2>/dev/null | grep USER\..*PROCLIB`
  echo "    "procs = $procs >> $LOG_FILE
  for proclib in $procs
  do
    echo "    "proclib = $proclib >> $LOG_FILE
    ./ocopyshr.sh $proclib $membername
    if [[ $? > 0 ]]
    then
      echo "  "Unable to write to $proclib, try another PROCLIB >> $LOG_FILE
    else
      echo "  "PROC $membername placed in $proclib
      echo "  PROC $membername placed in $proclib " >> $LOG_FILE
      tsocmd delete "'$userid.zowetemp.clist' " 1>/dev/null 2>/dev/null
      exitzero
    fi
  done
fi

# echo Try JES2 PROCLIB concatenation
opercmd "d t" 1> /dev/null 2> /dev/null  # is 'opercmd' available?
if [[ $? > 0 ]]
then
  echo "  "Unable to read JES2 PROCLIB concatenation with opercmd REXX exec >> $LOG_FILE
else
  procs=`opercmd '$d proclib'|grep DSNAME=.*\.PROCLIB|sed 's/.*DSNAME=\(.*\)\.PROCLIB.*/\1.PROCLIB/'`
  echo "  "procs = $procs >> $LOG_FILE
  for proclib in $procs
  do
    echo "  "proclib = $proclib >> $LOG_FILE
    ./ocopyshr.sh $proclib $membername 
    if [[ $? > 0 ]]
    then
      : # echo Unable to write to $proclib, try another PROCLIB
    else
      echo "  "PROC $membername placed in $proclib
      echo "  PROC $membername placed in $proclib " >> $LOG_FILE
      tsocmd delete "'$userid.zowetemp.clist' " 1>/dev/null 2>/dev/null
      exitzero
    fi
  done
fi

# echo Try master JES2 JCL
tsocmd oput \'sys1.parmlib\(mstjcl00\)\' \'mstjcl00\' 1>/dev/null 2>/dev/null
if [[ $? > 0 ]]
then
  : # echo Unable to read master JES2 JCL
  rm mstjcl00
else
  procs=`grep PROCLIB mstjcl00 | sed 's/.*DSN=\(.*\)\.PROCLIB.*/\1.PROCLIB/'`
  rm mstjcl00
  for proclib in $procs
  do
      ./ocopyshr.sh $proclib $membername
      if [[ $? > 0 ]]
      then
        : # echo Unable to write to $proclib, try another PROCLIB
      else
        echo "  "PROC $membername placed in $proclib
        echo "  PROC $membername placed in $proclib " >> LOG_FILE
        tsocmd delete "'$userid.zowetemp.clist' " 1>/dev/null 2>/dev/null
        exitzero
      fi
    done
  fi

  # echo Try SYS1.PROCLIB
  ./ocopyshr.sh $proclib $membername
  if [[ $? > 0 ]]
  then
    : # echo Unable to write to SYS1.PROCLIB
  else
    echo "  "PROC $membername placed in $proclib
    echo "PROC $membername placed in $proclib " >> $LOG_FILE
    tsocmd delete "'$userid.zowetemp.clist' " 1>/dev/null 2>/dev/null
    exitzero
  fi

  tsocmd delete "'$userid.zowetemp.clist' " 1>/dev/null 2>/dev/null

  cp $ussfile $ZOWE_ROOT_DIR/ZOWESVR.JCL
 
  echo "  "Failed to put ZOWESVR.JCL in a PROCLIB dataset.
  echo "  "Please add it manually from $ZOWE_ROOT_DIR/ZOWESVR.JCL to your PROCLIB
  echo "    ""To find PROCLIB datasets, issue /\$D PROCLIB in SDSF"
  echo "Unable to create the proclib " >> $LOG_FILE

exitone
