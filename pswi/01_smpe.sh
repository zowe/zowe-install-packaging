#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
WORKFLOW_DS=${CSIHLQ}.SMPE.WORKFLOW

echo ""
echo ""
echo "Script for creation of ZOWE SMP/E environment..."
echo "Host                        :" $ZOSMF_URL
echo "Port                        :" $ZOSMF_PORT
echo "z/OSMF system               :" $ZOSMF_SYSTEM
echo "Dataset with workflows      :" $WORKFLOW_DS
echo "SMPE workflow name          :" $SMPE_WF_NAME

# URLs
CREATE_SMPE_WF_URL="${BASE_URL}/zosmf/workflow/rest/1.0/workflows"
SMPE_WF_LIST_URL="${BASE_URL}/zosmf/workflow/rest/1.0/workflows?owner=${ZOSMF_USER}&workflowName=${SMPE_WF_NAME}"

# JSONs 

ADD_WORKFLOW_JSON='{"workflowName":"'$SMPE_WF_NAME'",
"workflowDefinitionFile":"'${DIR}'/SMPE20",
"system":"'$ZOSMF_SYSTEM'",
"owner":"'$ZOSMF_USER'",
"assignToOwner" :true,
"variables":[{"name":"hlq","value":"'$SMPEHLQ'"},
{"name":"csihlq","value":"'$CSIHLQ'"},
{"name":"fmid","value":"'$FMID'"},
{"name":"rfdsnpfx","value":"'$RFDSNPFX'"},
{"name":"csivol","value":"'$VOLUME'"},
{"name":"tzone","value":"'$TZONE'"},
{"name":"dzone","value":"'$DZONE'"},
{"name":"thlq","value":"'$CSIHLQ'.T"}, 
{"name":"dhlq","value":"'$CSIHLQ'.D"},
{"name":"tvol","value":"'$VOLUME'"},
{"name":"dvol","value":"'$VOLUME'"},
{"name":"mountPath","value":"'$ZOWE_MOUNT'"}]}'

# Store SMPE wokflow in the WORKFLOW dataset
echo "Uploading workflow SMPE into ${DIR} directory thru SSH"

cd workflows

sshpass -p${ZOSMF_PASS} sftp -o HostKeyAlgorithms=+ssh-rsa -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${DIR}
put SMPE20
EOF
cd ..

# Get workflowKey for SMPE workflow owned by user
echo "Get workflowKey for SMPE workflow if it exists."

RESP=`curl -s $SMPE_WF_LIST_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
WFKEY=`echo $RESP | grep -o '"workflowKey":".*"' | cut -f4 -d\"`
if [ -n "$WFKEY" ]
then
SMPE_WORKFLOW_URL="${CREATE_SMPE_WF_URL}/${WFKEY}"

echo "Deleting an SMPE workflow."
RESP=`curl -s $SMPE_WORKFLOW_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
fi

# Create workflow with REST API
echo 'Invoking REST API to create SMPE workflow.'

RESP=`curl -s $CREATE_SMPE_WF_URL -k -X "POST" -d "$ADD_WORKFLOW_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
if [ $? -gt 0 ];then exit -1;fi
WFKEY=`echo $RESP | grep -o '"workflowKey":".*"' | cut -f4 -d\"`
WORKFLOW_URL="${CREATE_SMPE_WF_URL}/${WFKEY}"

# Run workflow
echo "Invoking REST API to start a SMPE workflow."

RESP=`curl -s ${WORKFLOW_URL}/operations/start -k -X "PUT" -d "{}" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
if [ $? -gt 0 ];then exit -1;fi
STATUS=""
until [ "$STATUS" = "FINISHED" ]
do
sleep 20


# Get the result of the workflow
RESP=`curl -s ${WORKFLOW_URL} -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
if [ $? -gt 0 ];then exit -1;fi
STATUS_NAME=`echo $RESP | grep -o '"statusName":".*"' | cut -f4 -d\"`

if [ "$STATUS_NAME" = "in-progress" ]
then
  echo "Workflow ended with an error."
  echo $RESP
  exit -1
elif [ "$STATUS_NAME" = "complete" ]
then
  echo "Workflow finished successfully."
  STATUS="FINISHED"
fi
done

