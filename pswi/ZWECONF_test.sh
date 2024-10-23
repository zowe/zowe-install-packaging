export ZOSMF_URL="https://zzow07.zowe.marist.cloud"
export ZOSMF_PORT=10443
export ZOSMF_SYSTEM="S0W1"
export JOBNAME="ZWECONF1"
export HOST=${ZOSMF_URL#https:\/\/}
export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
WORK_MOUNT="/tmp"

echo "Changing runtime path in ZWECONF.properties."

cp ../workflows/files/ZWECONF.properties ./ZWECONF.properties
sed "s|runtimeDirectory=|runtimeDirectory=${WORK_MOUNT}|g" ./ZWECONF.properties > _ZWECONF
sed "s|java_home=|java_home=#delete_me#|g" _ZWECONF > ZWECONF
sed "s|node_home=|node_home=#delete_me#|g" ZWECONF > _ZWECONF

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

echo "//${ZOSMF_SYSTEM} JOB (1),'PSWI',MSGCLASS=A,REGION=0M" > JCL
echo "/*JOBPARM SYSAFF=(${ZOSMF_SYSTEM})" >> JCL
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
rm zowe_.yaml
EOF

pwd

cp ../example-zowe.yaml example-zowe.yaml

diff example-zowe.yaml zowe_.yaml > diff.txt || true

diff diff.txt scripts/base_diff.txt > final_diff.txt || true

concat=`cat final_diff.txt`

if [ -n "$concat" ]
then
  echo "There are some discrepancies between the example-zowe.yaml and the zowe.yaml created by ZWECONF.xml workflow."
  echo "Please add or delete the workflow so everything is there."
  echo "First line is from the example and the line bellow is from the workflow."
  echo $concat
  exit -1
fi
