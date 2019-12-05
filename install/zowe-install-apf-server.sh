#!/bin/sh

################################################################################
# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
# 
# SPDX-License-Identifier: EPL-2.0
# 
# Copyright Contributors to the Zowe Project.
################################################################################

PREV_DIR=`pwd`
cd $(dirname $0)

 #Note - these are sed replaced in zowe-copy-xmem.sh, so don't change without checking that
INSTALL_DIR=$PWD/..
SCRIPT_DIR=${INSTALL_DIR}/scripts/zss
ZSS=${INSTALL_DIR}/files/zss
OPERCMD=${SCRIPT_DIR}/../opercmd

XMEM_ELEMENT_ID=ZWEX
XMEM_MODULE=ZWESIS01
XMEM_AUX_MODULE=ZWESAUX
XMEM_PARM=${XMEM_ELEMENT_ID}MP00
XMEM_JCL=${XMEM_ELEMENT_ID}MSTC
XMEM_AUX_JCL=${XMEM_ELEMENT_ID}ASTC
XMEM_KEY=4
XMEM_SCHED=${XMEM_ELEMENT_ID}SCH
XMEM_STC_PREFIX=${XMEM_ELEMENT_ID}
XMEM_STC_GROUP=STCGROUP
XMEM_PROFILE=${XMEM_ELEMENT_ID}.IS

loadlibOk=false
apfOk=false
parmlibOk=false
proclibOk=false
pptOk=false
safOk=false
stcUserOk=false
stcProfileOk=false
xmemProfileOk=false
xmemProfileAccessOk=false


sh -c "rm -rf ${ZSS} && mkdir -p ${ZSS} && cd ${ZSS} && pax -ppx -rf ../zss.pax"
chmod +x ${OPERCMD}
chmod +x ${SCRIPT_DIR}/*
. ${SCRIPT_DIR}/zowe-xmem-parse-yaml.sh

# TODO remove once https://github.com/zowe/zss/issues/94 is resolved
mv ${ZSS}/SAMPLIB/ZWESIS01 ${ZSS}/SAMPLIB/${XMEM_JCL}
mv ${ZSS}/SAMPLIB/ZWESAUX ${ZSS}/SAMPLIB/${XMEM_AUX_JCL}
mv ${ZSS}/SAMPLIB/ZWESIP00 ${ZSS}/SAMPLIB/${XMEM_PARM}
mv ${ZSS}/SAMPLIB/ZWESISCH ${ZSS}/SAMPLIB/${XMEM_SCHED}

# MVS install steps

# 0. Prepare STC JCL
sed -e "s/${XMEM_ELEMENT_ID}.SISLOAD/${XMEM_LOADLIB}/g" \
    -e "s/${XMEM_ELEMENT_ID}.SISSAMP/${XMEM_PARMLIB}/g" \
    -e "s/NAME='ZWESIS_STD'/NAME='${XMEM_SERVER_NAME}'/g" \
    ${ZSS}/SAMPLIB/${XMEM_JCL} > ${ZSS}/SAMPLIB/${XMEM_JCL}.tmp
sed -e "s/zis-loadlib/${XMEM_LOADLIB}/g" \
    ${ZSS}/SAMPLIB/${XMEM_AUX_JCL} > ${ZSS}/SAMPLIB/${XMEM_AUX_JCL}.tmp

# 1. Deploy loadlib
echo
echo "************************ Install step 'LOADLIB' start **************************"
echo $SCRIPT_DIR/zowe-xmem-deploy-loadmodule.sh
loadlibCmd1="sh $SCRIPT_DIR/zowe-xmem-deploy-loadmodule.sh ${ZSS} ${XMEM_LOADLIB} ${XMEM_MODULE}"
loadlibCmd2="sh $SCRIPT_DIR/zowe-xmem-deploy-loadmodule.sh ${ZSS} ${XMEM_LOADLIB} ${XMEM_AUX_MODULE}"
$loadlibCmd1 && $loadlibCmd2
if [[ $? -eq 0 ]]
then
  loadlibOk=true
fi
echo "************************ Install step 'LOADLIB' end ****************************"

# 2. APF-authorize loadlib
echo
echo "************************ Install step 'APF-auth' start *************************"
apfCmd1="sh $SCRIPT_DIR/zowe-xmem-apf.sh ${OPERCMD} ${XMEM_LOADLIB}"
if $loadlibOk ; then
  $apfCmd1
  if [[ $? -eq 0 ]]; then
    apfOk=true
  fi
else
  echo "Error: skip this step due to previous errors"
fi
echo "************************ Install step 'APF-auth' end ***************************"

# 3. Deploy parmlib
echo
echo "************************ Install step 'PARMLIB' start **************************"
parmlibCmd1="sh $SCRIPT_DIR/zowe-xmem-deploy-parmlib.sh ${ZSS} ${XMEM_PARMLIB} ${XMEM_PARM}"
$parmlibCmd1
if [[ $? -eq 0 ]]
then
  parmlibOk=true
fi
echo "************************ Install step 'PARMLIB' end ****************************"


# 4. Deploy PROCLIB
echo
echo "************************ Install step 'PROCLIB' start **************************"
proclibCmd1="sh $SCRIPT_DIR/zowe-xmem-deploy-proclib.sh ${ZSS} ${XMEM_PROCLIB} ${XMEM_JCL}.tmp ${XMEM_JCL}"
proclibCmd2="sh $SCRIPT_DIR/zowe-xmem-deploy-proclib.sh ${ZSS} ${XMEM_PROCLIB} ${XMEM_AUX_JCL}.tmp ${XMEM_AUX_JCL}"
$proclibCmd1 && $proclibCmd2
if [[ $? -eq 0 ]]
then
  proclibOk=true
fi
echo "************************ Install step 'PROCLIB' end ****************************"


# 5. PPT-entry
echo
echo "************************ Install step 'PPT-entry' start ************************"
pptCmd1="sh $SCRIPT_DIR/zowe-xmem-ppt.sh ${OPERCMD} ${XMEM_MODULE} ${XMEM_KEY}"
pptCmd2="sh $SCRIPT_DIR/zowe-xmem-ppt.sh ${OPERCMD} ${XMEM_AUX_MODULE} ${XMEM_KEY}"
$pptCmd1 && $pptCmd2
if [[ $? -eq 0 ]]
then
  pptOk=true
fi
echo "************************ Install step 'PPT-entry' end **************************"




# Security install steps

function checkJob {
jobname=$1
tsocmd status ${jobname} 2>/dev/null | grep "JOB ${jobname}(S.*[0-9]*) EXECUTING" > /dev/null
if [[ $? -eq 0 ]]
then
  true 
else
  false
fi
}


# 6. Get SAF
echo
echo "************************ Install step 'SAF-type' start *************************"
echo "Get SAF"
for saf in RACF ACF2 TSS
do
  if checkJob $saf; then
    echo "Info:  SAF=${saf}"
    safOk=true
    break
  fi
done
if ! $safOk ; then
  echo "Error:  SAF has not been found"
fi
echo "************************ Install step 'SAF-type' end ***************************"

if $safOk ; then


  # 7. Handle STC user
  echo
  echo "************************ Install step 'STC user' start *************************"
  stcUserCmd1="sh $SCRIPT_DIR/zowe-xmem-check-user.sh ${saf} ${XMEM_STC_USER}"
  stcUserCmd2="sh $SCRIPT_DIR/zowe-xmem-define-stc-user.sh ${OPERCMD} ${saf} ${XMEM_STC_USER} ${XMEM_STC_USER_UID} ${XMEM_STC_GROUP}"
  $stcUserCmd1
  rc=$?
  if [[ $rc -eq 1 ]]; then
    if [[ ${XMEM_STC_USER_UID} == "" ]] || [[ ${XMEM_STC_GROUP} == "" ]]; then
      echo "Error:  APF server STC user UID and STC user group must be specified to define STC user"
    else
      $stcUserCmd2
      if [[ $? -eq 0 ]]; then
        stcUserOk=true
      fi
    fi
  elif [[ $rc -eq 0 ]]; then
    stcUserOk=true
  fi
  echo "************************ Install step 'STC user' end ***************************"


  # 8. Handle STC profile
  echo
  echo "************************ Install step 'STC profile' start **********************"
  stcProfileCmd1="sh $SCRIPT_DIR/zowe-xmem-check-stc-profile.sh ${saf} ${XMEM_STC_PREFIX}"
  stcProfileCmd2="sh $SCRIPT_DIR/zowe-xmem-define-stc-profile.sh ${OPERCMD} ${saf} ${XMEM_STC_PREFIX} ${XMEM_STC_USER} ${XMEM_STC_GROUP}"
  $stcProfileCmd1
  rc=$?
  if [[ $rc -eq 1 ]]; then
    if [[ ${XMEM_STC_GROUP} == "" ]]; then
      echo "Error:  STC user group must be specified to define STC profile"
    else
      $stcProfileCmd2
      if [[ $? -eq 0 ]]; then
        stcProfileOk=true
      fi
    fi
  elif [[ $rc -eq 0 ]]; then
    stcProfileOk=true
  fi
  echo "************************ Install step 'STC profile' end ************************"


  # 9. Handle security profile
  echo
  echo "************************ Install step 'Security profile' start *****************"
  xmemProfileCmd1="sh $SCRIPT_DIR/zowe-xmem-check-profile.sh ${saf} FACILITY ${XMEM_PROFILE} ${ZOWE_USER}"
  xmemProfileCmd2="sh $SCRIPT_DIR/zowe-xmem-define-xmem-profile.sh ${saf} ${XMEM_PROFILE} ${ZOWE_TSS_FAC_OWNER}"
  $xmemProfileCmd1
  rc=$?
  if [[ $rc -eq 1 ]]; then
    $xmemProfileCmd2
    if [[ $? -eq 0 ]]; then
      xmemProfileOk=true
    fi
  elif [[ $rc -eq 0 ]]; then
    xmemProfileOk=true
  fi
  echo "************************ Install step 'Security profile' end *******************"


  # 10. Check access
  echo
  echo "************************ Install step 'Security profile access' start **********"
  xmemAccessCmd1="sh $SCRIPT_DIR/zowe-xmem-check-access.sh ${saf} FACILITY ${XMEM_PROFILE} ${ZOWE_USER}"
  xmemAccessCmd2="sh $SCRIPT_DIR/zowe-xmem-permit.sh ${saf} ${XMEM_PROFILE} ${ZOWE_USER}"
  if [[ "$xmemProfileOk" = "true" ]]; then
    $xmemAccessCmd1
    rc=$?
    if [[ $rc -eq 1 ]]; then
      $xmemAccessCmd2
      if [[ $? -eq 0 ]]; then
        xmemProfileAccessOk=true
      fi
    elif [[ $rc -eq 0 ]]; then
      xmemProfileAccessOk=true
    fi
  fi
  echo "************************ Install step 'Security profile access' end ************"

else
  echo
  echo "Error: skip the security installation steps due to previous errors"
fi

echo
echo "********************************************************************************"
echo "************************************ Report ************************************"
echo "********************************************************************************"

echo
if $loadlibOk ; then
  echo "LOADLIB - Ok"
else
  echo "LOADLIB - Error"
  echo "Please correct errors and re-run the following scripts:"
  echo $loadlibCmd1
  echo $loadlibCmd2
fi

echo
if $apfOk ; then
  echo "APF-auth - Ok"
else
  echo "APF-auth - Error"
  echo "Please correct errors and re-run the following scripts:"
  echo $apfCmd1
fi

echo
if $parmlibOk ; then
  echo "PARMLIB - Ok"
else
  echo "PARMLIB - Error"
  echo "Please correct errors and re-run the following scripts:"
  echo $parmlibCmd1
fi

echo
if $proclibOk ; then
  echo "PROCLIB - Ok"
else
  echo "PROCLIB - Error"
  echo "Please correct errors and re-run the following scripts:"
  echo $proclibCmd1
  echo $proclibCmd2
fi

echo
if $pptOk ; then
  echo "PPT-entry - Ok"
else
  echo "PPT-entry - Error"
  echo "Please add the provided PPT entries (zss/samplib/${XMEM_SCHED}) to your system PARMLIB"
  echo "and update the configuration using 'SET SCH=xx' operator command"
  echo "Re-run the following scripts to validate the changes:"
  echo $pptCmd1
  echo $pptCmd2
fi

echo
if $safOk ; then
  echo "SAF type - Ok"
else
  echo "SAF type - Error"
fi

echo
if $stcUserOk ; then
  echo "STC user - Ok"
elif ! $safOk ; then
  echo "STC user - N/A"
else
  echo "STC user - Error"
  echo "Please correct errors and re-run the following scripts:"
  echo $stcUserCmd1
  echo $stcUserCmd2
fi

echo
if $stcProfileOk ; then
  echo "STC profile - Ok"
elif ! $safOk ; then
  echo "STC profile - N/A"
else
  echo "STC profile - Error"
  echo "Please correct errors and re-run the following scripts:"
  echo $stcProfileCmd1
  echo $stcProfileCmd2
fi

echo
if $xmemProfileOk ; then
  echo "Security profile - Ok"
elif ! $safOk ; then
  echo "Security profile - N/A"
else
  echo "Security profile - Error"
  echo "Please correct errors and re-run the following scripts:"
  echo $xmemProfileCmd1
  echo $xmemProfileCmd2
fi

echo
if $xmemProfileAccessOk ; then
  echo "Security profile access - Ok"
elif ! $safOk ; then
  echo "Security profile access - N/A"
else
  echo "Security profile access - Error"
  echo "Please correct errors and re-run the following scripts:"
  echo $xmemAccessCmd1
  echo $xmemAccessCmd2
fi


rm  ${ZSS}/SAMPLIB/${XMEM_JCL}.tmp 1>/dev/null 2>/dev/null

# Ensure IZUSVR has UPDATE access to BPX.SERVER and BPX.DAEMON
# For zssServer to be able to operate correctly 
# and READ access to BPX.JOBNAME to allow Zowe START to set job names
profile_refresh=0
for profile in SERVER DAEMON JOBNAME
do
    tsocmd rl facility "*" 2>/dev/null | grep BPX\.$profile >/dev/null
    if [[ $? -ne 0 ]]
    then
        # profile BPX\.$profile is not defined
        # Define the BPX facility
        tsocmd "RDEFINE FACILITY BPX.$profile UACC(NONE)" 2>/dev/null  1>/dev/null
        if [[ $? -ne 0 ]]
        then
          echo RDEFINE failed for BPX.$profile, please issue this command
          echo as a user with the required RACF privilege
          echo "    " "RDEFINE FACILITY BPX.$profile UACC(NONE)"
        fi 
        profile_refresh=1
    fi

    if [[ $profile = JOBNAME ]]
    then
      access=READ
    else
      access=UPDATE
    fi

    tsocmd rl facility bpx.$profile authuser 2>/dev/null |grep "IZUSVR *$access" >/dev/null
    if [[ $? -ne 0 ]]
    then
        # User IZUSVR does not have $access access to profile BPX\.$profile
        # Permit IZUSVR to update the BPX facilties 
        tsocmd "PERMIT BPX.$profile CLASS(FACILITY) ID(IZUSVR) ACCESS($access)" 2>/dev/null  1>/dev/null
        if [[ $? -ne 0 ]]
        then
          echo PERMIT failed for BPX.$profile, please issue this command
          echo as a user with the required RACF privilege
          echo "    " "PERMIT BPX.$profile CLASS(FACILITY) ID(IZUSVR) ACCESS($access)"
        fi 
        profile_refresh=1
    fi
done
if [[ profile_refresh -eq 1 ]]
then
     # Activate these changes 
    tsocmd "SETROPTS RACLIST(FACILITY) REFRESH " 2>/dev/null
    if [[ $? -ne 0 ]]
    then
          echo SETROPTS failed for class FACILITY, please issue this command
          echo as a user with the required RACF privilege
          echo "    " "SETROPTS RACLIST(FACILITY) REFRESH "
    fi 
fi

echo
echo "********************************************************************************"
echo "********************************************************************************"
echo "********************************************************************************"

cd $PREV_DIR

exit 0
