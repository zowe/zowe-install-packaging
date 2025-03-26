#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
LOG_FILE=$LOG_DIR/log_pswi_presmpe_cleanup

echo ""
echo ""
echo "Script for clean-up ZOWE RELFILES and PTFs"
echo "Host                               :" $ZOSMF_URL
echo "Port                               :" $ZOSMF_PORT
echo "z/OSMF system                      :" $ZOSMF_SYSTEM
echo "HLQ for RELFILES and PTFs          :" $SMPE
echo "Temp zFS                           :" $TMP_ZFS
echo "Directory for logs                 :" $LOGDIR

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
    if [ -n "$RESP" ]; then
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

# Delete pre-SMPE datasets

echo ${JOBST1} >JCL
echo ${JOBST2} >>JCL
echo "//DELTZOWE EXEC PGM=IDCAMS" >>JCL
echo "//SYSPRINT DD SYSOUT=*" >>JCL
echo "//SYSIN    DD *" >>JCL
echo " DELETE ${SMPE}.** MASK" >>JCL
echo " SET MAXCC=0" >>JCL
echo "/*" >>JCL

sh scripts/submit_jcl.sh "$(cat JCL)"
rm JCL
