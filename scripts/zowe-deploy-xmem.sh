#!/bin/sh

# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
# 
# SPDX-License-Identifier: EPL-2.0
# 
# Copyright Contributors to the Zowe Project.

BASEDIR=$(dirname "$0")

ZSS=$BASEDIR/../../zss
XMEM_ELEMENT_ID=ZWES
XMEM_MODULE=${XMEM_ELEMENT_ID}IS01
XMEM_LOADLIB=${USER}.LOADLIB
XMEM_PARMLIB=${USER}.PARMLIB
XMEM_PARM=${XMEM_ELEMENT_ID}IP00
XMEM_JCL=${XMEM_ELEMENT_ID}IS01
XMEM_PROCLIB=${USER}.PROCLIB
XMEM_KEY=4
XMEM_SCHED=${XMEM_ELEMENT_ID}ISCH
XMEM_STC_USER=${XMEM_ELEMENT_ID}ISTC
XMEM_STC_USER_UID=11111
XMEM_STC_PREFIX=${XMEM_ELEMENT_ID}IS
XMEM_STC_GROUP=STCGROUP
XMEM_PROFILE=${XMEM_ELEMENT_ID}.IS
ZOWE_USER=${USER}

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

# MVS install steps

# 0. Preapre STC JCL
cp ${ZSS}/SAMPLIB/${XMEM_JCL} ${ZSS}/SAMPLIB/${XMEM_JCL}.tmp
sed -i "s/${XMEM_ELEMENT_ID}.SISLOAD/${XMEM_LOADLIB}/g" ${ZSS}/SAMPLIB/${XMEM_JCL}.tmp
sed -i "s/${XMEM_ELEMENT_ID}.SISSAMP/${XMEM_PARMLIB}/g" ${ZSS}/SAMPLIB/${XMEM_JCL}.tmp

# 1. Deploy loadlib
echo
echo "************************ Install step 'LOADLIB' start **************************"
loadlibCmd1="sh $BASEDIR/zowe-xmem-deploy-loadmodule.sh ${ZSS} ${XMEM_LOADLIB} ${XMEM_MODULE}"
$loadlibCmd1
if [[ $? -eq 0 ]]
then
  loadlibOk=true
fi
echo "************************ Install step 'LOADLIB' end ****************************"

# 2. APF-authorize loadlib
echo
echo "************************ Install step 'APF-auth' start *************************"
apfCmd1="sh $BASEDIR/zowe-xmem-apf.sh ${XMEM_LOADLIB}"
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
parmlibCmd1="sh $BASEDIR/zowe-xmem-deploy-parmlib.sh ${ZSS} ${XMEM_PARMLIB} ${XMEM_PARM}"
$parmlibCmd1
if [[ $? -eq 0 ]]
then
  parmlibOk=true
fi
echo "************************ Install step 'PARMLIB' end ****************************"


# 4. Deploy PROCLIB
echo
echo "************************ Install step 'PROCLIB' start **************************"
proclibCmd1="sh $BASEDIR/zowe-xmem-deploy-proclib.sh ${ZSS} ${XMEM_PROCLIB} ${XMEM_JCL}.tmp ${XMEM_JCL}"
$proclibCmd1
if [[ $? -eq 0 ]]
then
  proclibOk=true
fi
echo "************************ Install step 'PROCLIB' end ****************************"


# 5. PPT-entry
echo
echo "************************ Install step 'PPT-entry' start ************************"
pptCmd1="sh $BASEDIR/zowe-xmem-ppt.sh ${XMEM_MODULE} ${XMEM_KEY}"
$pptCmd1
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
  stcUserCmd1="sh $BASEDIR/zowe-xmem-check-user.sh ${saf} ${XMEM_STC_USER}"
  stcUserCmd2="sh $BASEDIR/zowe-xmem-define-stc-user.sh ${saf} ${XMEM_STC_USER} ${XMEM_STC_USER_UID} ${XMEM_STC_GROUP}"
  $stcUserCmd1
  rc=$?
  if [[ $rc -eq 1 ]]; then
    $stcUserCmd2
    if [[ $? -eq 0 ]]; then
      stcUserOk=true
    fi
  elif [[ $rc -eq 0 ]]; then
    stcUserOk=true
  fi
  echo "************************ Install step 'STC user' end ***************************"


  # 8. Handle STC profile
  echo
  echo "************************ Install step 'STC profile' start **********************"
  stcProfileCmd1="sh $BASEDIR/zowe-xmem-check-stc-profile.sh ${saf} ${XMEM_STC_PREFIX}"
  stcProfileCmd2="sh $BASEDIR/zowe-xmem-define-stc-profile.sh ${saf} ${XMEM_STC_PREFIX} ${XMEM_STC_USER} ${XMEM_STC_GROUP}"
  $stcProfileCmd1
  rc=$?
  if [[ $rc -eq 1 ]]; then
    $stcProfileCmd2
    if [[ $? -eq 0 ]]; then
      stcProfileOk=true
    fi
  elif [[ $rc -eq 0 ]]; then
    stcProfileOk=true
  fi
  echo "************************ Install step 'STC profile' end ************************"


  # 9. Handle security profile
  echo
  echo "************************ Install step 'Security profile' start *****************"
  xmemProfileCmd1="sh $BASEDIR/zowe-xmem-check-profile.sh ${saf} FACILITY ${XMEM_PROFILE} ${ZOWE_USER}"
  xmemProfileCmd2="sh $BASEDIR/zowe-xmem-define-xmem-profile.sh ${saf} ${XMEM_PROFILE}"
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
  xmemAccessCmd1="sh $BASEDIR/zowe-xmem-check-access.sh ${saf} FACILITY ${XMEM_PROFILE} ${ZOWE_USER}"
  xmemAccessCmd2="sh $BASEDIR/zowe-xmem-permit.sh ${saf} ${XMEM_PROFILE} ${ZOWE_USER}"
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
fi

echo
if $pptOk ; then
  echo "PPT-entry - Ok"
else
  echo "PPT-entry - Error"
  echo "Please add the provided PPT entry (zss/samplib/${XMEM_SCHED}) to your system PARMLIB"
  echo "and update the configuration using 'SET SCH=xx' operator command"
  echo "Re-run the following scripts to validate the changes:"
  echo $pptCmd1
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

echo
echo "********************************************************************************"
echo "********************************************************************************"
echo "********************************************************************************"

rm  ${ZSS}/SAMPLIB/${XMEM_JCL}.tmp 1>/dev/null 2>/dev/null
exit 0

