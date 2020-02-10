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

# Verify that the Zowe pre-reqs are in place before you install Zowe on z/OS
# Note:  This script does not change anything on your system.

# Testing:  You must set these variables before you run this script:
# INSTALL_DIR=/u/tstradm/zowe/zowe-0.9.0       # this is the test location for testing this script on MV3B.  Remove this line before shipping.  

# Run this script AFTER you un-PAX the Zowe PAX file.

# Assume this script is invoked from the 'install' directory.  
#
#  This script may invoke others later, e.g.  giza-packaging/Zoeinstall/verify*.sh

echo Script zowe-check-prereqs.sh started

# This script is expected to be located in 'install' directory
# otherwise you must set INSTALL_DIR to the Zowe install directory before you run this script
# e.g. export INSTALL_DIR=/u/tstradm/zowe/zowe-0.9.0/install

if [[ -n "${INSTALL_DIR}" ]]
then 
    echo Info: INSTALL_DIR environment variable is set to ${INSTALL_DIR}
else 
    echo Info: INSTALL_DIR environment variable is empty
    if [[ `basename $PWD` != install ]]
    then
        echo Warning: You are not in the \'install\' directory
        echo Warning: '${INSTALL_DIR} is not set'
        echo Warning: '${INSTALL_DIR} must be set to the Zowe install directory'
        echo Warning: script will run, but with errors
    else
        INSTALL_DIR=`pwd`
        echo Info: INSTALL_DIR environment variable is now set to ${INSTALL_DIR}
    fi    
fi

echo
echo Check entries in the install directory
instdirOK=1
for dir in files install licenses scripts
do
  ls ${INSTALL_DIR}/../$dir >/dev/null
  if [[ $? -ne 0 ]]
  then
    echo Error: directory \"$dir\" not found in ${INSTALL_DIR}/..
    instdirOK=0
  fi
done
if [[ $instdirOK -eq 1 ]]
then
  echo OK
fi

# The user running this script requires certain basic privileges to list the resources that are to be checked.

echo
echo Check user has the basic auth to list the resources
basicauthOK=1
msg=`tsocmd lu izusvr 2>/dev/null | head -1`

case $msg in
UNABLE\ TO\ LOCATE\ USER\ *) 
  echo Error:  User IZUSVR is not defined 
  echo Warning: IZUADMIN, IZUGUEST and IZUUNGRP will not be checked as a result
  basicauthOK=0
;;

NOT\ AUTHORIZED\ TO\ LIST\ *) 
  echo Info:  User IZUSVR is defined but you are not authorized to list it
  echo Warning: IZUADMIN, IZUGUEST and IZUUNGRP will not be checked as a result   
;;

USER=IZUSVR\ *) 
  # echo OK:  User IZUSVR is defined and you are authorized to list it  

  echo
  echo Check RACF or other SAF security settings are correct
  tsocmd lg izuadmin 2>/dev/null |grep IZUSVR >/dev/null
  if [[ $? -ne 0 ]]
  then
    echo Error: user IZUSVR is not in group IZUADMIN
    basicauthOK=0
  fi

  echo
  echo Check IZUGUEST
  tsocmd lg izuungrp 2>/dev/null |grep IZUGUEST >/dev/null
  if [[ $? -ne 0 ]]
  then
    echo Error: user IZUGUEST is not in group IZUUNGRP
    basicauthOK=0 
  fi

;;

*) 
  echo Error:  Unexpected response to RACF LISTUSER command
  echo $msg
  basicauthOK=0
esac
if [[ $basicauthOK -eq 1 ]]
then 
  echo OK
fi


echo
echo Is opercmd available?

if [[ -r ${INSTALL_DIR}/../scripts/opercmd ]]
then 
  chmod a+x ${INSTALL_DIR}/../scripts/opercmd
  if [[ $? -ne 0 ]]
  then
    echo Error:  Unable to make opercmd executable
  else 
    ${INSTALL_DIR}/../scripts/opercmd "d t" 1> /dev/null 2> /dev/null  # is 'opercmd' available and working?
    if [[ $? -ne 0 ]]
    then
      echo Error: Unable to run opercmd REXX exec from # >> $LOG_FILE
      ls -l ${INSTALL_DIR}/../scripts/opercmd # try to list opercmd
      echo Warning: z/OS release will not be checked
    else
    # use opercmd

      echo
      echo OK: opercmd is available
      echo
      echo Check z/OS RELEASE
      release=`${INSTALL_DIR}/../scripts/opercmd 'd iplinfo'|grep RELEASE`
      # the selected line will look like this ...
      # RELEASE z/OS 02.03.00    LICENSE = z/OS
      
      vrm=`echo $release | sed 's+.*RELEASE z/OS \(........\).*+\1+'`
      echo release of z/OS is $release
      if [[ $vrm < "02.02.00" ]]
            then echo Error: version $vrm not supported
            else echo OK: version $vrm is supported
      fi
    fi
  fi 
else 
  echo Error: Cannot access opercmd
  echo Warning: z/OS release will not be checked 
fi 
# z/OSMF and other pre-req jobs are up and running
# z/OS V2R2 with PTF UI46658 or z/OS V2R3, 

# z/OS UNIX System Services enabled, and 
# Integrated Cryptographic Service Facility (ICSF) configured and started.


echo
echo Check install user is a member of the IZUADMIN group

# get list of groups this user is in
echo "Installer's TSO userid:"
userid=`tsocmd lu 2>/dev/null |sed -n 's/.*USER=\([^ ]*\) *NAME=.*/\1/p'`
echo $userid

echo "installer's group(s):"
tsocmd lu 2>/dev/null |sed -n 's/.*GROUP=\([^ ]*\) *AUTH=.*/\1/p' | grep "^IZUADMIN$"
if [[ $? -ne 0 ]]
then
  echo Error:  User $userid is not a member of the IZUADMIN group
else  
  echo OK
fi

if [ -z ${TEMP_DIR+x} ]; then
    TEMP_DIR=${TMPDIR:-/tmp}
fi


# 1- RDEFINE OPERCMDS MVS.START.** UACC(NONE)
# 2- PERMIT MVS.START.** CLASS(OPERCMDS) ACC(UPDATE) ID(IBMUSER)
# 3- SETR GENERIC(OPERCMDS) RACLIST(OPERCMDS) REFRESH


match_profile ()
{
  className=$1    # the CLASS containing all the profiles that user can access
  profileName=$2  # the profile that we want to match in that list
  tsocmd "search class($className) user($userid)" 2> /dev/null |sed 's/\(.*\) .*/\1/' > $TEMP_DIR/find_profile.out
  while read string 
  do
    
    l=$((`echo $profileName | wc -c`))  # length of profile we're looking for, including null terminator
    i=1
    while [[ $i -lt $l ]]
    do
        r=`echo $string       | cut -c $i,$i` # ith char from RACF definition
        p=`echo $profileName  | cut -c $i,$i` # ith char from profile we're looking for

        if [[ $r = '*' ]]
        then
          rm        $TEMP_DIR/find_profile.out
          return 0  # asterisk matches rest of string
        fi

        if [[ $r != $p ]]
        then
          break   # mismatch char for this profile, try next
        fi

        i=$((i+1))
    done

    if [[ $i -eq $l ]]
    then
      rm        $TEMP_DIR/find_profile.out
      return 0  # whole string matched
    fi


  done <    $TEMP_DIR/find_profile.out
  rm        $TEMP_DIR/find_profile.out
  return 1    # no strings matched
}

echo
echo Check user can issue START/STOP commands

startstopOK=1
for profile in "MVS.START.STC" "MVS.STOP.STC"
do
  match_profile "OPERCMDS" $profile
  if [[ $? -eq 0 ]]
  then
    : # echo OK: User $userid is authorized to use OPERCMDS $profile
  else 
    echo Error: User $userid is not authorized to use OPERCMDS $profile
    startstopOK=0
  fi
done
if [[ $startstopOK -eq 1 ]]
then 
  echo OK
fi 

echo
echo Check user can issue SDSF commands
# Check ISF access:
# Here are the latest set of TSO commands to resolve the issue: 
# 1- RDEFINE SDSF  ISF*.** UACC(NONE)
# 2- PERMIT  ISF*.** CLASS(SDSF) ACC(READ) ID(IBMUSER)
# 3- SETR GENERIC(SDSF) RACLIST(SDSF) REFRESH 

sdsfOK=1
for profile in "ISF.CONNECT" "ISFATTR" "ISFCMD.ODSP" "ISFOPER"
do
  match_profile "SDSF" $profile
  if [[ $? -eq 0 ]]
  then
    : # echo OK: User $userid is authorized to use SDSF $profile
  else 
    echo Info: User $userid is not authorized to use SDSF $profile
    sdsfOK=0
  fi
done

if [[ $sdsfOK -eq 1 ]]
then 
  echo OK
fi 

    # 4.2 Jobs with JCT
echo
echo Check z/OSMF servers are up

zosmfOK=1

for jobname in IZUANG1 IZUSVR1 # RACF
do
  tsocmd status ${jobname} 2>/dev/null | grep "JOB ${jobname}(S.*[0-9]*) EXECUTING" >/dev/null
  if [[ $? -eq 0 ]]
  then 
      : # echo OK: Job ${jobname} is executing

  else 
      echo Error: Job ${jobname} is not executing
      zosmfOK=0
  fi
done
if [[ $zosmfOK -eq 1 ]]
then 
  echo OK
fi
    
# 9. z/OSMF    

# --- this section is TBD ------
# IEFC001I PROCEDURE IZUSVR1 WAS EXPANDED USING SYSTEM LIBRARY ADCD.Z23B.PROCLIB

    # 4.2  Ability to to send HTTP requests to zOSMF with X-CSRF-ZOSMF-HEADER.
    # When trying to call zOSMF such as using the URL:
    # https://aquagiza21.fyre.ibm.com:10443/zosmf/restfiles/ds?dslevel=tstradm

# https://9.20.65.202:10443/zosmf/info  on ukzowe1
# https://9.20.65.202:10443/zosmf/restjobs/jobs (you need to log in)

# IEE252I MEMBER IZUPRM00 FOUND IN ADCD.Z23B.PARMLIB
# CSRF_SWITCH(OFF) 



echo
echo Check enough free space is available in target z/OS USS HFS install folder

# 7. Check interface name specified in /zaas1/scripts/ipupdate.sh ?
# 8. /u/tstradm/.profile file exists



# 9.1. Node is installed and working
# IBM SDK for Node.js z/OS Version 6.14.4 or later.

echo 
echo Check job ICSF or CSF  # required for node commands
ICSF=0  # no active job
for jobname in ICSF CSF # jobname will be one or the other
do
  ${INSTALL_DIR}/../scripts/opercmd d j,${jobname}|grep " ${jobname} .* A=[0-9,A-F][0-9,A-F][0-9,A-F][0-9,A-F] " > /dev/null
  if [[ $? -eq 0 ]]
  then
    ICSF=1  # found job active
    break
  fi
done


if [[ $ICSF -eq 1 ]]
then 
  echo OK # jobname ICSF or CSF is running
else
  echo Error: jobname ICSF or CSF is not running
fi


echo
echo Check Node version

nodeVersion=`node --version 2>&1`
if [[ $? -ne 0 ]]
then
  # node version error
  echo $nodeVersion | grep 'not found' > /dev/null
  if [[ $? -eq 0 ]]   # the 'node' command was not found.
  then 
    echo Error: node not found in your path, trying /etc/profile
    nodeVersion=    # set it to empty string 

    # 3. /etc/profile?
    ls /etc/profile 1> /dev/null
    if [[ $? -ne 0 ]]
    then 
        echo Info: /etc/profile not found
    else
        grep "^ *export *NODE_HOME=.* *$" /etc/profile 1> /dev/null
        if [[ $? -ne 0 ]]
        then 
            echo Info: \"export NODE_HOME\" not found in /etc/profile
        else
            node_set=`sed -n 's/^ *export *NODE_HOME=\(.*\) *$/\1/p' /etc/profile`
            if [[ ! -n "$node_set" ]]
            then
                echo Warning: NODE_HOME is empty in /etc/profile
            else
                nodehome=$node_set
                # echo Info: Found in /etc/profile

                nodeVersion=`$nodehome/bin/node --version` # also works if it's a symlink
                if [[ $? -ne 0 ]]
                then 
                    echo Error: Failed to obtain version of $nodehome/bin/node
                    nodeVersion=    # set it to empty string 
                fi
            fi 
        fi
    fi    
  else
    echo Error: Node version error
    echo ${nodeVersion}
    nodeVersion=    # set it to empty string 
  fi
fi

# echo node version is \"$nodeVersion\"

if [[ -n "${nodeVersion}" ]]
then 
    # nodeVersion is not empty 
    if [[ "$nodeVersion" < "v6.14.4" ]]
          then 
            echo Error: node version $nodeVersion is less than minimum level required
          else 
            echo OK # : node version $nodeVersion is at least the minimum level required
    fi
else
    echo Error: can not determine node version
fi


# 9.2 Java installed and right version
# IBM Java Version 1.8 or later.
# /java/java80_64/J8.0_64/bin/java
# it might be here ... ls /*
# /usr/lpp/java/current_64
# /usr/lpp/java/current_64/bin/java -version   # on zD&T
echo
echo Check Java version
java -version 1>/dev/null 2>/dev/null
if [[ $? -ne 0 ]]
then
  echo Error: failed to find java 
else
  response=`java -version 2>&1 | grep ^"java version"`
  if [[ $? -ne 0 ]]
  then
    echo Error: failed to find java version number
  else
    if [[ "$response" < "java version \"1.8" ]]
    then 
      echo Error: $response is less than minimum level required
    else 
      echo OK # $response is at least the minimum level required
    fi
  fi
fi


# C:\GIZA\giza-packaging\ZoeInstall>

# - external scripts, in preparation:
# checkConfig.sh
# checkPorts.sh


# verifyConfig.sh
# # verifyhttpserver.jstemplate
# # verifyhttpsserver.jstemplate
# verifyptfs.sh
# verifyZoe.sh
# # verifyzosmf.jstemplate
# verifyzosmf.sh
# verifyzosmfaccess.sh

# print out the state of all the CEE_RUNOPTS 

echo
echo Check CEE_RUNOPTS

set | grep _CEE_RUNOPTS
echo 

# also the LDA can be used to confirm both REGION choices 
# and the effects of any IEFUSI exits. 
    # LDA is found using DDLIST, an ISPF command dialog, which is not directly runnable from a shell script.
    # Or use REXX.
    # http://www.askthezoslady.com/tso-region-size-really-means/
    # Either way, not a 1-line command.  
    # z/OSMF IZUSVR1 sets MEMLIMIT=6G on the PGM=BPXBATSL  statement

echo
echo Check USS AUTOCVT

${INSTALL_DIR}/../scripts/opercmd "D OMVS,o" | grep "AUTOCVT *= OFF" > /dev/null
if [[ $? -ne 0 ]]
then
  echo Warning:  OMVS AUTOCVT is not set to OFF.  Files may appear in wrong code page.
else
  echo OK:  OMVS AUTOCVT is set to OFF
fi

#  These pertain to the environment of the installer user, not IZUSVR
#
if [[ -n "${_BPXK_AUTOCVT}" ]]
then 
  echo Warning: _BPXK_AUTOCVT is set to ${_BPXK_AUTOCVT}
else 
  echo OK: _BPXK_AUTOCVT is not set
fi 

if [[ -n "${_BPXK_CCSIDS}" ]]
then 
  echo Warning: _BPXK_CCSIDS is set to ${_BPXK_CCSIDS}
else 
  echo OK: _BPXK_CCSIDS is not set
fi 

echo
echo Script zowe-check-prereqs.sh ended


