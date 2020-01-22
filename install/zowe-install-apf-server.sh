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

XMEM_ELEMENT_ID=ZWES
XMEM_MODULE=${XMEM_ELEMENT_ID}IS01
XMEM_AUX_MODULE=${XMEM_ELEMENT_ID}AUX
XMEM_PARM=${XMEM_ELEMENT_ID}IP00
XMEM_JCL=${XMEM_ELEMENT_ID}ISTC
XMEM_AUX_JCL=${XMEM_ELEMENT_ID}ASTC
XMEM_KEY=4
XMEM_SCHED=${XMEM_ELEMENT_ID}ISCH
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


chmod +x ${OPERCMD}
chmod +x ${SCRIPT_DIR}/*
. ${SCRIPT_DIR}/zowe-xmem-parse-yaml.sh

# MVS install steps

# 2. APF-authorize loadlib
echo
echo "************************ Install step 'APF-auth' start *************************"
apfCmd1="sh $SCRIPT_DIR/zowe-xmem-apf.sh ${OPERCMD} ${XMEM_LOADLIB}"
$apfCmd1
if [[ $? -eq 0 ]]; then
  apfOk=true
fi
echo "************************ Install step 'APF-auth' end ***************************"

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

echo
echo "********************************************************************************"
echo "************************************ Report ************************************"
echo "********************************************************************************"

echo
if $apfOk ; then
  echo "APF-auth - Ok"
else
  echo "APF-auth - Error"
  echo "Please correct errors and re-run the following scripts:"
  echo $apfCmd1
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
echo "********************************************************************************"
echo "********************************************************************************"
echo "********************************************************************************"

cd $PREV_DIR

exit 0
