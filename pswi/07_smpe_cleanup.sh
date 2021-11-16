#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
LOG_FILE=${LOGDIR}log_pswi_"`date +%y-%j-%H-%M-%S`"

echo ""
echo ""
echo "Script for clean-up ZOWE SMPE"
echo "Host                               :" $ZOSMF_URL
echo "Port                               :" $ZOSMF_PORT
echo "z/OSMF system                      :" $ZOSMF_SYSTEM
echo "HLQ for datasets                   :" $CSIHLQ
echo "ZOWE zFS                           :" $ZOWE_ZFS
echo "Directory for logs                 :" $LOGDIR

# URLs
ACTION_ZOWE_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/${ZOWE_ZFS}"

# JSONs  
UNMOUNT_ZFS_JSON='{"action":"unmount"}'

function check_response {
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

echo "Invoking REST API to unmount SMPE zFS ${ZOWE_ZFS} from its mountpoint."

RESP=`curl -s $ACTION_ZOWE_ZFS_URL -k -X "PUT" -d "$UNMOUNT_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
check_response "${RESP}" $?

# Delete SMPE datasets
read -r -d '' DELJCL << END
${JOBST1}
${JOBST2}
//DELTZOWE EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
 DELETE ${CSIHLQ}.** MASK
 SET MAXCC=0
/*
END
sh scripts/submit_jcl.sh "$DELJCL"
