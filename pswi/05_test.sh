#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"

echo ""
echo ""
echo "Script for testing a Portable Software Instance..."
echo "Host                   :" $ZOSMF_URL
echo "Port                   :" $ZOSMF_PORT
echo "PSWI name              :" $PSWI
echo "z/OSMF system          :" $ZOSMF_SYSTEM
echo "Test HLQ               :" $TEST_HLQ
echo "Test mount point       :" $TEST_MOUNT
echo "Job name               :" $JOBNAME
echo "Deploy name            :" $DEPLOY_NAME
echo "Software instance name :" $DEPLOY_NAME 
echo "Temporary directory    :" $TMP_MOUNT
echo "Temporary zFS          :" $TMP_ZFS
echo "Work zFS               :" $WORK_ZFS # For z/OSMF v2.3
echo "Work mount point       :" $WORK_MOUNT # For z/OSMF v2.3
echo "Storage Class          :" $STORCLAS
echo "Volume                 :" $VOLUME
echo "ACCOUNT                :" $ACCOUNT
echo "SYSAFF                 :" $SYSAFF
echo "z/OSMF version         :" $ZOSMF_V

NEW_PSWI_JSON='{"name":"'${PSWI}'","system":"'${ZOSMF_SYSTEM}'","description":"Zowe PSWI for testing","directory":"'${EXPORT}'"}'

# Check if temp zFS for PSWI is mounted
echo "Checking/mounting ${TMP_ZFS}"
sh scripts/tmp_mounts.sh "${TMP_ZFS}" "${TMP_MOUNT}"
if [ $? -gt 0 ];then exit -1;fi 

cd ../.pax
sshpass -p${ZOSMF_PASS} sftp -o HostKeyAlgorithms=+ssh-rsa -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${TMP_MOUNT}
put ${SWI_NAME}.pax.Z
EOF
cd ../pswi

# Unpax the directory (create directory for test_mount)
echo "UnPAXing the final PSWI."

echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//UNPAXDIR EXEC PGM=BPXBATCH" >> JCL
echo "//STDOUT DD SYSOUT=*" >> JCL
echo "//STDERR DD SYSOUT=*" >> JCL
echo "//STDPARM  DD *" >> JCL
echo "SH set -x;set -e;" >> JCL
echo "mkdir -p ${EXPORT};" >> JCL
echo "cd ${EXPORT};" >> JCL
echo "pax -rv -f ${TMP_MOUNT}/${SWI_NAME}.pax.Z;" >> JCL
echo "rm ${TMP_MOUNT}/${SWI_NAME}.pax.Z;" >> JCL
echo "/*" >> JCL

sh scripts/submit_jcl.sh "`cat JCL`"
if [ $? -gt 0 ];then exit -1;fi
rm JCL


if [ "$ZOSMF_V" = "2.4" ]; then
  echo "Not covering deployment on z/OSMF 2.4 yet."
#TODO: it's same as for 2.3 without work zfs - manage this in deploy_test_2_3.py and add api call to register PSWI
# z/OSMF 2.4

# Delete Portable Software Instance if it already exists
# No check of return code because if it does not exist the script would fail (return code 404)
#echo 'Invoking REST API to delete the portable software instance if the previous test did not delete it.'
#
#RESP=`curl -s ${BASE_URL}/zosmf/swmgmt/pswi/${ZOSMF_SYSTEM}/${PSWI} -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS `
#
## The response is in format "statusurl":"https:\/\/:ZOSMF_URL:post\/restofurl"
#echo 'Invoking REST API to register a Portable Software Instance'
#
#RESP=`curl -s ${BASE_URL}/zosmf/swmgmt/pswi -k -X "POST" -d "$NEW_PSWI_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS `
#sh scripts/check_response.sh "${RESP}" $?
#if [ $? -gt 0 ];then exit -1;fi
#
#EXPORT_STATUS_URL=`echo $RESP | grep -o '"statusurl":".*"' | cut -f4 -d\" | tr -d '\' 2>/dev/null`
#if [ "$EXPORT_STATUS_URL" == "" ]
#then
#  echo "No response from the REST API call."
#  exit -1
#fi
#
#STATUS=""
#until [ "$STATUS" == "complete" ]
#do
#RESP=`curl -s $EXPORT_STATUS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
#sh scripts/check_response.sh "${RESP}" $?
#if [ $? -gt 0 ];then exit -1;fi
#
#STATUS=`echo $RESP | grep -o '"status":".*"' | cut -f4 -d\"`
#echo "The status is: "$STATUS
#
#if [ "$STATUS" != "complete" ] && [ "$STATUS" != "running" ]
#then
#  echo "Registration of PSWI in z/OSMF failed."
#  exit -1
#fi
#sleep 3
#done
#
#google-chrome --version
#RC=$?
#
#if [ $RC -gt 0 ];
#then
#echo "Checking if the system is CentOS or RHEL."
#yum version
#RC=$?
#
#if [ $RC -gt 0 ];
#then 
#  echo "Installing Chrome on Debian/Ubuntu."
#  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
#  sudo apt-get install ./google-chrome-stable_current_*.rpm
#else 
#  echo "Installing Chrome on CentOS or RHEL."
#  wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
#  sudo yum install ./google-chrome-stable_current_*.rpm
#fi
#fi
#
#echo "Downloading Chromedriver"
#version=`google-chrome --product-version`
#url="https://chromedriver.storage.googleapis.com/"${version}"/chromedriver_linux64.zip"
#rm chromedriver.zip
#rm chromedriver
#wget $url -nc -O chromedriver.zip
#
## Run the deployment test
#echo " Running the deployment test for z/OSMF version 2.4"
#DIR=`pwd`
#PATH=$DIR/scripts/spool_files.sh:$PATH
#pip install selenium
#pip install requests
#
#export HEADLESS="true"
#python ../PSI_testing/deploy_test.py
#
#rm chromedriver

else
# z/OSMF 2.3

# Check if work zFS for PSWI is mounted
echo "Checking/mounting ${WORK_ZFS}"
sh scripts/tmp_mounts.sh "${WORK_ZFS}" "${WORK_MOUNT}"
if [ $? -gt 0 ];then exit -1;fi 

# Run the deployment test
echo " Running the deployment test for z/OSMF version 2.3"

pip install requests
python scripts/deploy_test_2_3.py

fi
