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

echo "Registering/testing the configuration workflow ${TEST_MOUNT}/files/workflows/ZWECONF.xml"
sh scripts/wf_run_test.sh "${TEST_MOUNT}/files/workflows/ZWECONF.xml"
if [ $? -gt 0 ];then exit -1;fi

echo "Changing runtime path in ZWECONF.properties."

cp ../workflows/files/ZWECONF.properties ./ZWECONF.properties
sed "s|runtimeDirectory=|runtimeDirectory=${WORK_MOUNT}|g" ./ZWECONF.properties > _ZWECONF
sed "s|java_home=|java_home=#delete_me#|g" _ZWECONF > ZWECONF
sed "s|node_home=|node_home=#delete_me#|g" ZWECONF > _ZWECONF
#TODO:delete java home and node home from the yaml because it is not set in the example-zowe.yml

echo "Changing the configuration workflow to be fully automated."

cp ../workflows/files/ZWECONF.xml ./ZWECONF.xml
sed "s|<autoEnable>false|<autoEnable>true|g" ./ZWECONF.xml > ZWECONFX

sshpass -p${ZOSMF_PASS} sftp -o HostKeyAlgorithms=+ssh-rsa -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${ZZOW_SSH_PORT} ${ZOSMF_USER}@${HOST} << EOF
cd ${WORK_MOUNT}
put _ZWECONF
put ZWECONFX
EOF

echo "Testing the configuration workflow ${WORK_MOUNT}/ZWECONFX"
sh scripts/wf_run_test.sh "${WORK_MOUNT}/ZWECONFX" "run" "ZWECONF" "${WORK_MOUNT}/_ZWECONF"
if [ $? -gt 0 ];then exit -1;fi

echo "Converting zowe.yaml"

echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//UNPAXDIR EXEC PGM=BPXBATCH" >> JCL
echo "//STDOUT DD SYSOUT=*" >> JCL
echo "//STDERR DD SYSOUT=*" >> JCL
echo "//STDPARM  DD *" >> JCL
echo "SH set -x;set -e;" >> JCL
echo "cd ${WORK_MOUNT};" >> JCL
echo "iconv -f IBM-1047 -t ISO8859-1 zowe.yaml > zowe_.yaml;" >> JCL
echo "/*" >> JCL

sh scripts/submit_jcl.sh "`cat JCL`"
if [ $? -gt 0 ];then exit -1;fi
rm JCL

sshpass -p${ZOSMF_PASS} sftp -o HostKeyAlgorithms=+ssh-rsa -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${ZZOW_SSH_PORT} ${ZOSMF_USER}@${HOST} << EOF
cd ${WORK_MOUNT}
get zowe_.yaml
EOF

cat zowe_.yaml

pwd

cp ../example-zowe.yaml example-zowe.yaml

diff example-zowe.yaml zowe_.yaml
