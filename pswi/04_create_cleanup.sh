#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
LOG_FILE=${LOGDIR}log_pswi_"`date +%y-%j-%H-%M-%S`"

echo ""
echo ""
echo "Script for clean-up after Portable Software Instance creation..."
echo "Host                        :" $ZOSMF_URL
echo "Port                        :" $ZOSMF_PORT
echo "z/OSMF system               :" $ZOSMF_SYSTEM
echo "SWI name                    :" $SWI_NAME
echo "CSI HLQ                     :" $CSIHLQ
echo "Existing DSN                :" $EXPORT_DSN
echo "Temporary zFS               :" $TMP_ZFS
echo "Work zFS                    :" $WORK_ZFS # For z/OSMF v2.3
echo "ZOWE zFS                    :" $ZOWE_ZFS
echo "Directory for logs          :" $LOGDIR
echo "z/OSMF version              :" $ZOSMF_V

# URLs
ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/zfs/${TMP_ZFS}"
ACTION_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/${TMP_ZFS}"
WORK_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/zfs/${WORK_ZFS}"
ACTION_WORK_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/${WORK_ZFS}"
ACTION_ZOWE_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/${ZOWE_ZFS}"
DELETE_SWI_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${SWI_NAME}"
EXPORT_DSN_URL="${BASE_URL}/zosmf/restfiles/ds/${EXPORT_DSN}"
WORKFLOW_DSN_URL="${BASE_URL}/zosmf/restfiles/ds/${WORKFLOW_DSN}"

# JSONs  
UNMOUNT_ZFS_JSON='{"action":"unmount"}'


check_response() {
  RESP=$1
  RESPCODE=$2
  
  REASON=`echo $RESP | grep -o '"reason":'`
  EMPTY=`echo $RESP | grep -o '\[\]'`
  MSG=`echo $RESP | grep -o '"messageText":'`
  if [ "$REASON" != "" ] || [ "$MSG" != "" ] 
  then
    echo  "Info: Logging to file ${LOG_FILE}."
    echo   "$RESP" >> $LOG_FILE
  fi
  if [ "$EMPTY" != "" ]
  then
    echo  "Info: Logging to file ${LOG_FILE}."
    echo   "$RESP" >> $LOG_FILE
  fi
  if [ $RESPCODE -ne 0 ]
    then
    echo  "Info: Logging to file ${LOG_FILE}."
    if [ "$RESP" != "" ]
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

# Delete the Software instance
echo 'Invoking REST API to delete the first Software Instance.'

RESP=`curl -s $DELETE_SWI_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?

# Delete data set with export jobs
echo "Invoking REST API to delete ${EXPORT_DSN} data set with export jobs."

RESP=`curl -s $EXPORT_DSN_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?

# Delete
echo "Invoking REST API to delete ${WORKFLOW_DSN} data set."

RESP=`curl -s $WORKFLOW_DSN_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?

# Unmount
echo "Invoking REST API to unmount zFS ${TMP_ZFS} from its mountpoint."

RESP=`curl -s $ACTION_ZFS_URL -k -X "PUT" -d "$UNMOUNT_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?

if [ "$ZOSMF_V" == "2.3" ]
then
echo "Invoking REST API to unmount zFS ${WORK_ZFS} from its mountpoint."

RESP=`curl -s $ACTION_WORK_ZFS_URL -k -X "PUT" -d "$UNMOUNT_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?

sleep 20

echo "Invoking REST API to delete ${WORK_ZFS} zFS."

RESP=`curl -s $WORK_ZFS_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?
fi 

# Delete
echo "Invoking REST API to delete ${TMP_ZFS} zFS."

RESP=`curl -s $ZFS_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?

echo "Invoking REST API to unmount Zowe zFS ${ZOWE_ZFS} from its mountpoint."

RESP=`curl -s $ACTION_ZOWE_ZFS_URL -k -X "PUT" -d "$UNMOUNT_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?
