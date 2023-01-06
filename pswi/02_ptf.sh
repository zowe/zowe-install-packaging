#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
WORKFLOW_DS=${CSIHLQ}.SMPE.WORKFLOW

echo ""
echo ""
echo "Script for applying of PTFs into SMPE via workflow..."
echo "Host                        :" $ZOSMF_URL
echo "Port                        :" $ZOSMF_PORT
echo "z/OSMF system               :" $ZOSMF_SYSTEM
echo "CSI HLQ                     :" $CSIHLQ
echo "PTF dataset                 :" $SMPE
echo "1st PTF                     :" $PTF1
echo "2nd PTF                     :" $PTF2
echo "Dataset with workflows      :" $WORKFLOW_DS
echo "PTF workflow name           :" $PTF_WF_NAME

# URLs
CREATE_PTF_WF_URL="${BASE_URL}/zosmf/workflow/rest/1.0/workflows"
PTF_WF_LIST_URL="${BASE_URL}/zosmf/workflow/rest/1.0/workflows?owner=${ZOSMF_USER}&workflowName=${PTF_WF_NAME}"

# JSONs 
ADD_WORKFLOW_JSON='{"workflowName":"'$PTF_WF_NAME'",
"workflowDefinitionFile":"'${DIR}'/WFPTF",
"system":"'$ZOSMF_SYSTEM'",
"owner":"'$ZOSMF_USER'",
"assignToOwner" :true,
"variables":[{"name":"CSI","value":"'$CSIHLQ'"},
{"name":"PTFDATASET","value":"'$SMPE'"},
{"name":"TARGET","value":"'$TZONE'"},
{"name":"DISTRIBUTION","value":"'$DZONE'"},
{"name":"PTF1","value":"'$PTF1'"},
{"name":"PTF2","value":"'$PTF2'"},
{"name":"PTFNR","value":"'$PTFNR'"}]}'

cd workflows

sshpass -p${ZOSMF_PASS} sftp -o HostKeyAlgorithms=+ssh-rsa -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${DIR}
put WFPTF
EOF
cd ..

# Get workflowKey for PTF workflow owned by user
echo "Get workflowKey for PTF workflow if it exists."

RESP=`curl -s $PTF_WF_LIST_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
WFKEY=`echo $RESP | grep -o '"workflowKey":".*"' | cut -f4 -d\"`

if [ -n "$WFKEY" ]
then
PTF_WORKFLOW_URL="${CREATE_PTF_WF_URL}/${WFKEY}"

echo "Deleting a PTF workflow."
RESP=`curl -s $PTF_WORKFLOW_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
fi

# Create workflow with REST API
echo 'Invoking REST API to create ptf workflow.'

RESP=`curl -s $CREATE_PTF_WF_URL -k -X "POST" -d "$ADD_WORKFLOW_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
if [ $? -gt 0 ];then exit -1;fi
WFKEY=`echo $RESP | grep -o '"workflowKey":".*"' | cut -f4 -d\"`
WORKFLOW_URL="${CREATE_PTF_WF_URL}/${WFKEY}"

# Run workflow
echo "Invoking REST API to start a PTF apply workflow."

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
