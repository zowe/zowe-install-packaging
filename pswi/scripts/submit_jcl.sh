JCL=$1
JCL_LOG_DIR=$LOG_DIR/jobs/jcl

mkdir -p $JCL_LOG_DIR

echo "JCL to be submitted:"
echo "$JCL"

# Submit the JCL
echo 'Invoking REST API to run the job.'

RESP=$(curl -s ${BASE_URL}/zosmf/restjobs/jobs -k -X "PUT" -d "$JCL" -H "Content-Type: text/plain" -H "X-CSRF-ZOSMF-HEADER: A" -H "X-IBM-Intrdr-Class: A" -H "X-IBM-Intrdr-Recfm: F" -H "X-IBM-Intrdr-Lrecl: 80" -H "X-IBM-Intrdr-Mode: TEXT" --user $ZOSMF_USER:$ZOSMF_PASS)
sh scripts/check_response.sh "${RESP}" $?
JOB_STATUS_URL=$(echo $RESP | grep -o '"url":".*"' | cut -f4 -d\" | tr -d '\' 2>/dev/null)
if [ -z "$JOB_STATUS_URL" ]; then
  echo "No response from the REST API call." >>$LOG_DIR/report.txt
  exit -1
fi
JOBID=$(echo $RESP | grep -o '"jobid":".*"' | cut -f4 -d\")
JOBNAME=$(echo $RESP | grep -o '"jobname":".*"' | cut -f4 -d\")

echo "Job ${JOBNAME} ${JOBID} submitted."

# Check status of submitted job from the previous step
echo "Invoking REST API to check if the job ${JOBNAME} ${JOBID} has finished."
STATUS=""

until [ "$STATUS" = "OUTPUT" ]; do
  RESP=$(curl -s $JOB_STATUS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS)
  sh scripts/check_response.sh "${RESP}" $?
  STATUS=$(echo $RESP | grep -o '"status":".*"' | cut -f4 -d\")
  echo "The status of the job is ${STATUS}"
  if [ -f EXPJCL ]; then # If file with export JCL exists that mean that export JCL was submitted and it needs to wait longer
    sleep 30
  else
    sleep 5
  fi
done

# Check return code
RC=$(echo $RESP | grep -o '"retcode":".*"' | cut -f4 -d\")
echo "Return code of the job ${JOBNAME} ${JOBID} is ${RC}."

# Download spool files
echo "Downloading spool files."
sh scripts/spool_files.sh $JOBNAME $JOBID

echo "$JCL" >>$JCL_LOG_DIR/JCL_$JOBNAME_$JOBID

if [ "$RC" = "CC 0000" ]; then
  echo "${JOBNAME} ${JOBID} was completed."
else
  echo "${JOBNAME} ${JOBID} failed." >>$LOG_DIR/report.txt
  cat $JOBNAME/$JOBID >>$LOG_DIR/report.txt
  exit -1
fi
