#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"

echo ""
echo ""
echo "Script for testing a Portable Software Instance..."
echo "Host                   :" $ZOSMF_URL
echo "Port                   :" $ZOSMF_PORT
echo "SSH Port               :" $ZZOW_SSH_PORT
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
sshpass -p${ZOSMF_PASS} sftp -o HostKeyAlgorithms=+ssh-rsa -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${ZZOW_SSH_PORT} ${ZOSMF_USER}@${HOST} << EOF
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

# z/OSMF 2.3

# Check if work zFS for PSWI is mounted
echo "Checking/mounting ${WORK_ZFS}"
sh scripts/tmp_mounts.sh "${WORK_ZFS}" "${WORK_MOUNT}"
if [ $? -gt 0 ];then exit -1;fi 

# Run the deployment test
echo " Running the deployment test for z/OSMF version 2.3"

pip install requests
python scripts/deploy_test_2_3.py

echo "Mounting ${TEST_HLQ}.ZFS"
sh scripts/tmp_mounts.sh "${TEST_HLQ}.ZFS" "${TEST_MOUNT}"
if [ $? -gt 0 ];then exit -1;fi 

echo "Registering/testing the configuration workflow ${TEST_HLQ}.WORKFLOW(ZWECONF)"
sh scripts/wf_run_test.sh "${TEST_HLQ}.WORKFLOW(ZWECONF)"
if [ $? -gt 0 ];then exit -1;fi

echo "Registering/testing the configuration workflow ${TEST_MOUNT}/content/files/workflows/ZWECONF.xml"
sh scripts/wf_run_test.sh "${TEST_MOUNT}/files/workflows/ZWECONF.xml"
if [ $? -gt 0 ];then exit -1;fi
