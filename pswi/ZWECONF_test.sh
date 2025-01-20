export ZOSMF_URL="https://zzow10.zowe.marist.cloud"
export ZOSMF_PORT=10443
export ZOSMF_SYSTEM="S0W1"
export JOBNAME="ZWECONF1"
export HOST=${ZOSMF_URL#https:\/\/}
export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
CURR_TIME=$(date +%s)
export LOG_DIR="logs/$CURR_TIME"
mkdir -p $LOG_DIR
WORK_MOUNT="/tmp"

echo "Changing runtime path in ZWECONF.properties."

cp ../workflows/files/ZWECONF.properties ./ZWECONF.properties
sed "s|runtimeDirectory=|runtimeDirectory=${WORK_MOUNT}|g" ./ZWECONF.properties >_ZWECONF
sed "s|java_home=|java_home=#delete_me#|g" _ZWECONF >ZWECONF
sed "s|node_home=|node_home=#delete_me#|g" ZWECONF >_ZWECONF

echo "Changing the configuration workflow to be fully automated."

cp ../workflows/files/ZWECONF.xml ./ZWECONF.xml
sed "s|<autoEnable>false|<autoEnable>true|g" ./ZWECONF.xml >ZWECONFX

sshpass -p${ZOSMF_PASS} sftp -o HostKeyAlgorithms=+ssh-rsa -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${ZZOW_SSH_PORT} ${ZOSMF_USER}@${HOST} <<EOF
cd ${WORK_MOUNT}
put _ZWECONF
put ZWECONFX
EOF

echo "Testing the configuration workflow ${WORK_MOUNT}/ZWECONFX"
sh scripts/wf_run_test.sh "${WORK_MOUNT}/ZWECONFX" "run" "ZWECONF" "${WORK_MOUNT}/_ZWECONF"
if [ $? -gt 0 ]; then exit -1; fi

echo "Converting zowe.yaml"

echo "//${ZOSMF_SYSTEM} JOB (1),'PSWI',MSGCLASS=A,REGION=0M" >JCL
echo "/*JOBPARM SYSAFF=(${ZOSMF_SYSTEM})" >>JCL
echo "//UNPAXDIR EXEC PGM=BPXBATCH" >>JCL
echo "//STDOUT DD SYSOUT=*" >>JCL
echo "//STDERR DD SYSOUT=*" >>JCL
echo "//STDPARM  DD *" >>JCL
echo "SH set -x;set -e;" >>JCL
echo "cd ${WORK_MOUNT};" >>JCL
echo "iconv -f IBM-1047 -t ISO8859-1 zowe.yaml > zowe_.yaml;" >>JCL
echo "/*" >>JCL

sh scripts/submit_jcl.sh "$(cat JCL)"
if [ $? -gt 0 ]; then exit -1; fi
rm JCL

sshpass -p${ZOSMF_PASS} sftp -o HostKeyAlgorithms=+ssh-rsa -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${ZZOW_SSH_PORT} ${ZOSMF_USER}@${HOST} <<EOF
cd ${WORK_MOUNT}
get zowe_.yaml
rm zowe_.yaml
EOF

pwd

cp ../example-zowe.yaml example-zowe.yaml

diff example-zowe.yaml zowe_.yaml >diff.txt || true

diff diff.txt scripts/base_diff.txt >final_diff.txt || true

concat=$(cat final_diff.txt)

if [ -n "$concat" ]
then
  echo "There are some discrepancies between the example-zowe.yaml and the zowe.yaml created by ZWECONF.xml workflow."
  echo "Please add to or delete from the ZWECONF.xml workflow what needs or doesn't need to be there."
  echo "E.g. if there is a new variable you need to add it first to the workflow variables, then add the variable to the" 
  echo "'main_variables' step and then also to the step where the zowe.yaml is created."
  echo "If there was added/deleted just a comment in the example-zowe.yaml please add it also to the workflow so"
  echo "this step is not failing."
  echo "Here is the output from the diff command:" # They will surely know what is diff cmd, right
  while read -r line; do
    if [[ "$line" =~ ^\< ]]; then
      echo $line >> final_final_diff.txt
    fi
  done <final_diff.txt
  cat final_final_diff.txt
  echo "------------------------------------------------------------------------"
  echo "First line is from the example-zowe.yaml and the line bellow is from the"
  echo "zowe.yaml created by the ZWECONF.xm workflow."
  cp final_final_diff.txt $LOG_DIR/diff_output.txt
  exit -1
fi
