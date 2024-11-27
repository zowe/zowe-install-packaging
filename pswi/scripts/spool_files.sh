# $1 = JOBNAME
# $2 = JOBID

IDENTIFIER="${1}/${2}"
JOBNAME=${1}
JOB_OUTPUT_DIR=$LOG_DIR/jobs/output
JOB_OUTPUT_FILE=$JOB_OUTPUT_DIR/$JOBNAME_$2

RESP=$(curl -s ${BASE_URL}/zosmf/restjobs/jobs/${IDENTIFIER}/files -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS)
sh scripts/check_response.sh "$RESP" $?
if [ $? -gt 0 ]; then exit $?; fi

echo $RESP | sed 's/},/},\n/g' | grep -o '"records-url":".*records"' | cut -f4 -d\" | tr -d '\' 2>/dev/null 1>urls

mkdir -p $JOB_OUTPUT_DIR

while read -r line; do
  curl -s $line?mode=text -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS >>$JOB_OUTPUT_FILE
done <urls

rm urls

echo "Spool files can be found in the ${JOBNAME} directory."
