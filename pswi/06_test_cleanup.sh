#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
LOG_FILE=${LOGDIR}log_pswi_"`date +%y-%j-%H-%M-%S`"

echo ""
echo ""
echo "Script for clean-up after a testing of Portable Software Instance..."
echo "Host                        :" $ZOSMF_URL
echo "Port                        :" $ZOSMF_PORT
echo "z/OSMF system               :" $ZOSMF_SYSTEM
echo "HLQ for datasets            :" $TEST_HLQ
echo "Portable Software Instance  :" $PSWI
echo "Software instance name      :" $DEPLOY_NAME
echo "Temporary zFS               :" $TMP_ZFS
echo "Work zFS                    :" $WORK_ZFS # For z/OSMF v2.3
echo "Directory for logs          :" $LOGDIR
echo "ACCOUNT                     :" $ACCOUNT
echo "SYSAFF                      :" $SYSAFF
echo "z/OSMF version              :" $ZOSMF_V


# URLs
DELETE_PSWI_URL="${BASE_URL}/zosmf/swmgmt/pswi/${ZOSMF_SYSTEM}/${PSWI}"
LIST_ZFS_URL="${BASE_URL}/zosmf/restfiles/ds?dslevel=${TEST_HLQ}.**.ZFS"
WORKFLOW_LIST_URL="${BASE_URL}/zosmf/workflow/rest/1.0/workflows?owner=${ZOSMF_USER}&workflowName=${WORKFLOW_NAME}.*"
DELETE_DEPL_SWI_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${DEPLOY_NAME}"
ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/zfs/${TMP_ZFS}"
WORK_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/zfs/${TMP_ZFS}"
ACTION_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/${TMP_ZFS}"
WORK_ACTION_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/${TMP_ZFS}"

# JSON  
UNMOUNT_ZFS_JSON='{"action":"unmount"}'


check_response() {
  RESP=$1
  RESPCODE=$2
  
  REASON=`echo $RESP | grep -o '"reason":'`
  EMPTY=`echo $RESP | grep -o '\[\]'`
  MSG=`echo $RESP | grep -o '"messageText":'`
  if [ -n "$REASON" ] || [ -n "$MSG" ] 
  then
    echo  "Info: Logging to file ${LOG_FILE}."
    echo   "$RESP" >> $LOG_FILE
  fi 
  if [ -n "$EMPTY" ]
  then
    echo  "Info: Logging to file ${LOG_FILE}."
    echo   "$RESP" >> $LOG_FILE
  fi
  if [ $RESPCODE -ne 0 ]
    then
    echo  "Info: Logging to file ${LOG_FILE}."
    if [ -n "$RESP" ]
    then
      echo   "$RESP" >> $LOG_FILE
    else
      echo "REST API call wasn't successful." >> $LOG_FILE
    fi 
  else
    echo "REST API call was successful."
  fi
  
  return 
 }

# Create a log file
touch $LOG_FILE
 
## Delete the Software instance
#echo "Invoking REST API to delete the Software Instance created by deployment."
#
#RESP=`curl -s $DELETE_DEPL_SWI_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
#check_response "${RESP}" $?

if [ "$ZOSMF_V" = "2.4" ]
then

# Delete the Portable Software Instance
echo "Invoking REST API to delete the portable software instance."

RESP=`curl -s $DELETE_PSWI_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?
fi

# Obtain the list of ZFS
echo "Obtaining list of ${TEST_HLQ}.**.ZFS datasets."
RESP=`curl -s $LIST_ZFS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?
ZFSLIST=`echo $RESP | sed 's/},/},\n/g' | grep -oP '"dsname":".*"' | cut -f4 -d\"`

# Unmount
IFS=$'\n'
for ZFS in $ZFSLIST
do
echo "Invoking REST API to unmount zFS ${ZFS} from its mountpoint."

RESP=`curl -s ${BASE_URL}/zosmf/restfiles/mfs/${ZFS} -k -X "PUT" -d "$UNMOUNT_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?

done

# Unmount temporary ZFS
echo "Invoking REST API to unmount zFS ${TMP_ZFS} from its mountpoint."

RESP=`curl -s $ACTION_ZFS_URL -k -X "PUT" -d "$UNMOUNT_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?

sleep 20

# Delete
echo "Invoking REST API to delete ${TMP_ZFS} zFS."

RESP=`curl -s $ZFS_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?

if [ "$ZOSMF_V" == "2.3" ]
then
# Unmount work ZFS
echo "Invoking REST API to unmount zFS ${WORK_ZFS} from its mountpoint."

RESP=`curl -s $WORK_ACTION_ZFS_URL -k -X "PUT" -d "$UNMOUNT_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?

sleep 20

# Delete
echo "Invoking REST API to delete ${WORK_ZFS} zFS."

RESP=`curl -s $WORK_ZFS_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?  
fi

# Delete deployed datasets
echo "Deleting deployed datasets."

echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//DELTZOWE EXEC PGM=IDCAMS" >> JCL
echo "//SYSPRINT DD SYSOUT=*" >> JCL
echo "//SYSIN    DD *" >> JCL
echo " DELETE ${TEST_HLQ}.** MASK" >> JCL
echo " SET MAXCC=0" >> JCL
echo "/*" >> JCL

sh scripts/submit_jcl.sh "`cat JCL`"
rm JCL

if [ "$ZOSMF_V" = "2.4" ]
then
# Delete Post-deployment workflow in z/OSMF
echo "Invoking REST API to delete Post-deployment workflows."

# Get workflowKey for Post-deployment workflow owned by user 
RESP=`curl -s $WORKFLOW_LIST_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?
WFKEYS=`echo $RESP | sed 's/},/},\n/g' | grep -oP '"workflowKey":".*"' | cut -f4 -d\"`

IFS=$'\n'
for KEY in $WFKEYS
do

echo "Deleting a workflow."
RESP=`curl -s ${BASE_URL}/zosmf/workflow/rest/1.0/workflows/${KEY} -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?
  
done
fi
