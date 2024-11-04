#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
LOG_FILE=$LOG_DIR/log_create_cleanup.txt

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
ACTION_ZOWE_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/${ZOWE_ZFS}"
DELETE_SWI_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${SWI_NAME}"
EXPORT_DSN_URL="${BASE_URL}/zosmf/restfiles/ds/${EXPORT_DSN}"
WORKFLOW_DSN_URL="${BASE_URL}/zosmf/restfiles/ds/${WORKFLOW_DSN}"

# JSONs
UNMOUNT_ZFS_JSON='{"action":"unmount"}'

check_response() {
  RESP=$1
  RESPCODE=$2

  REASON=$(echo $RESP | grep -o '"reason":')
  EMPTY=$(echo $RESP | grep -o '\[\]')
  MSG=$(echo $RESP | grep -o '"messageText":')
  if [ -n "$REASON" ] || [ -n "$MSG" ]; then
    echo "Info: Logging to file ${LOG_FILE}."
    echo "$RESP" >>$LOG_FILE
  fi
  if [ -n "$EMPTY" ]; then
    echo "Info: Logging to file ${LOG_FILE}."
    echo "$RESP" >>$LOG_FILE
  fi
  if [ $RESPCODE -ne 0 ]; then
    echo "Info: Logging to file ${LOG_FILE}."
    if [ "$RESP" != "" ]; then
      echo "$RESP" >>$LOG_FILE
    else
      echo "REST API call wasn't successful." >>$LOG_FILE
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

RESP=$(curl -s $DELETE_SWI_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS)
check_response "${RESP}" $?

# Delete data set with export jobs
echo "Invoking REST API to delete ${EXPORT_DSN} data set with export jobs."

RESP=$(curl -s $EXPORT_DSN_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS)
check_response "${RESP}" $?

# Delete
echo "Invoking REST API to delete ${WORKFLOW_DSN} data set."

RESP=$(curl -s $WORKFLOW_DSN_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS)
check_response "${RESP}" $?

# Unmount and delete
echo "Unmounting and deleting zFS ${TMP_ZFS}."

echo ${JOBST1} >JCL
echo ${JOBST2} >>JCL
echo "//UNMNTZFS EXEC PGM=IKJEFT01,REGION=4096K,DYNAMNBR=50" >>JCL
echo "//SYSTSPRT DD SYSOUT=*" >>JCL
echo "//SYSTSOUT DD SYSOUT=*" >>JCL
echo "//SYSTSIN DD * " >>JCL
echo "UNMOUNT FILESYSTEM('${TMP_ZFS}') +  " >>JCL
echo "IMMEDIATE" >>JCL
echo "/*" >>JCL
echo "//DELTZFST EXEC PGM=IDCAMS" >>JCL
echo "//SYSPRINT DD SYSOUT=*" >>JCL
echo "//SYSIN    DD *" >>JCL
echo " DELETE ${TMP_ZFS}" >>JCL
echo "/*" >>JCL

sh scripts/submit_jcl.sh "$(cat JCL)"
# Not checking results so the script doesn't fail
rm JCL

if [ "$ZOSMF_V" = "2.3" ]; then
  # Unmount and delete
  echo "Unmounting and deleting zFS ${WORK_ZFS}."

  echo ${JOBST1} >JCL
  echo ${JOBST2} >>JCL
  echo "//UNMNTZFS EXEC PGM=IKJEFT01,REGION=4096K,DYNAMNBR=50" >>JCL
  echo "//SYSTSPRT DD SYSOUT=*" >>JCL
  echo "//SYSTSOUT DD SYSOUT=*" >>JCL
  echo "//SYSTSIN DD * " >>JCL
  echo "UNMOUNT FILESYSTEM('${WORK_ZFS}') +  " >>JCL
  echo "IMMEDIATE" >>JCL
  echo "/*" >>JCL
  echo "//DELTZFST EXEC PGM=IDCAMS" >>JCL
  echo "//SYSPRINT DD SYSOUT=*" >>JCL
  echo "//SYSIN    DD *" >>JCL
  echo " DELETE ${WORK_ZFS}" >>JCL
  echo "/*" >>JCL

  sh scripts/submit_jcl.sh "$(cat JCL)"
  # Not checking results so the script doesn't fail
  rm JCL
fi

echo "Invoking REST API to unmount Zowe zFS ${ZOWE_ZFS} from its mountpoint."

RESP=$(curl -s $ACTION_ZOWE_ZFS_URL -k -X "PUT" -d "$UNMOUNT_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS)
check_response "${RESP}" $?
