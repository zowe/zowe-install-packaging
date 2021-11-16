RESP=$1
RESPCODE=$2
  
REASON=`echo $RESP | grep -o '"reason":'`
MSG=`echo $RESP | grep -o '"messageText":'`
if [ "$REASON" != "" ] || [ "$MSG" != "" ]
then
  echo $RESP
  exit -1
fi 
if [ $RESPCODE -ne 0 ]
then
  echo "REST API call failed."
  echo $RESP
  exit -1
else
  echo "REST API call was successful."
fi
