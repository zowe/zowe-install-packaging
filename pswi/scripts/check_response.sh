RESP=$1
RESPCODE=$2

REASON=$(echo $RESP | grep -o '"reason":')
MSG=$(echo $RESP | grep -o '"messageText":')
if [ -n "$REASON" ] || [ -n "$MSG" ]; then
  echo $RESP >>$LOG_DIR/report.txt
  exit -1
fi
if [ $RESPCODE -ne 0 ]; then
  echo "REST API call failed." >>$LOG_DIR/report.txt
  echo $RESP >>$LOG_DIR/report.txt
  exit -1
else
  echo "REST API call was successful."
fi
