#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
WF_DEF_FILE=$1
INPUT_FILE=$2
run=$3

echo ""
echo ""
echo "Script for testing workflow and if specified running with defaults as well..."
echo "Host                        :" $ZOSMF_URL
echo "Port                        :" $ZOSMF_PORT
echo "z/OSMF system               :" $ZOSMF_SYSTEM
echo "Workflow definition file    :" $WF_DEF_FILE

WF_NAME="Testing workflows"
# URLs
CREATE_WF_URL="${BASE_URL}/zosmf/workflow/rest/1.0/workflows"
WF_LIST_URL="${BASE_URL}/zosmf/workflow/rest/1.0/workflows?owner=${ZOSMF_USER}&workflowName=${WF_NAME}"

# JSONs 
if [ -n "$INPUT_FILE" ]
then
ADD_WORKFLOW_JSON='{"workflowName":"'$WF_NAME'",
"workflowDefinitionFile":"'${WF_DEF_FILE}'",
"variableInputFile":"'${INPUT_FILE}'",
"system":"'$ZOSMF_SYSTEM'",
"owner":"'$ZOSMF_USER'",
"assignToOwner" :true}'
else
ADD_WORKFLOW_JSON='{"workflowName":"'$WF_NAME'",
"workflowDefinitionFile":"'${WF_DEF_FILE}'",
"system":"'$ZOSMF_SYSTEM'",
"owner":"'$ZOSMF_USER'",
"assignToOwner" :true}'
fi
# Get workflowKey for the workflow owned by user
echo "Get workflowKey for the workflow if it exists."

RESP=`curl -s $WF_LIST_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
WFKEY=`echo $RESP | grep -o '"workflowKey":".*"' | cut -f4 -d\"`

if [ -n "$WFKEY" ]
then
WORKFLOW_URL="${CREATE_WF_URL}/${WFKEY}"

echo "Deleting the workflow."
RESP=`curl -s $WORKFLOW_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
fi

set -ex
# Create workflow with REST API
echo 'Invoking REST API to create the workflow.'

RESP=`curl -s $CREATE_WF_URL -k -X "POST" -d "$ADD_WORKFLOW_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
if [ $? -gt 0 ];then exit -1;fi
WFKEY=`echo $RESP | grep -o '"workflowKey":".*"' | cut -f4 -d\"`
WORKFLOW_URL="${CREATE_WF_URL}/${WFKEY}"

if [ -n "${run}" ]
then
# Run workflow
echo "Invoking REST API to start the workflow."

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
fi

echo "Deleting the workflow."
RESP=`curl -s $WORKFLOW_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
