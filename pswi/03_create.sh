#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"

echo ""
echo ""
echo "Script for creating a Portable Software Instance..."
echo "Host               :" $ZOSMF_URL
echo "Port               :" $ZOSMF_PORT
echo "CSI HLQ            :" $CSIHLQ
echo "SMP/E zone         :" $ZONE
echo "z/OSMF system      :" $ZOSMF_SYSTEM
echo "SWI name           :" $SWI_NAME
echo "Existing DSN       :" $EXPORT_DSN
echo "Temporary zFS      :" $TMP_ZFS
echo "Temporary directory:" $TMP_MOUNT
echo "Work zFS           :" $WORK_ZFS # For z/OSMF v2.3
echo "Work mount point   :" $WORK_MOUNT # For z/OSMF v2.3
echo "ZOWE zFS           :" $ZOWE_ZFS
echo "ZOWE mount point   :" $ZOWE_MOUNT
echo "Volume             :" $VOLUME
echo "ACCOUNT            :" $ACCOUNT
echo "SYSAFF             :" $SYSAFF
echo "z/OSMF version     :" $ZOSMF_V

# JSONs      
ADD_SWI_JSON='{"name":"'${SWI_NAME}'","system":"'${ZOSMF_SYSTEM}'","description":"ZOWE v'${VERSION}' Portable Software Instance",
"globalzone":"'${GLOBAL_ZONE}'","targetzones":["'${TZONE}'"],"workflows":[{"name":"ZOWE Mount Workflow","description":"This workflow performs mount action of ZOWE zFS.",
"location": {"dsname":"'${WORKFLOW_DSN}'(ZWEWRF02)"}},{"name":"ZOWE Configuration of Zowe 2.0","description":"This workflow configures Zowe v2.0.",
"location": {"dsname":"'${WORKFLOW_DSN}'(ZWECONF)"}},{"name":"ZOWE Creation of CSR request workflow","description":"This workflow creates a certificate sign request.",
"location": {"dsname":"'${WORKFLOW_DSN}'(ZWECRECR)"}},{"name":"ZOWE Sign a CSR request","description":"This workflow signs the certificate sign request by a local CA.",
"location": {"dsname":"'${WORKFLOW_DSN}'(ZWESIGNC)"}},{"name":"ZOWE Load Authentication Certificate into ESM","description":"This workflow loads a signed client authentication certificate to the ESM.",
"location": {"dsname":"'${WORKFLOW_DSN}'(ZWELOADC)"}},{"name":"ZOWE Define key ring and certificates","description":"This workflow defines key ring and certificates for Zowe.",
"location": {"dsname":"'${WORKFLOW_DSN}'(ZWEKRING)"}}],"products":[{"prodname":"ZOWE","release":"'${VERSION}'","vendor":"Open Mainframe Project","url":"https://www.zowe.org/"}]}'
ADD_WORKFLOW_DSN_JSON='{"dirblk":5,"avgblk":25000,"dsorg":"PO","alcunit":"TRK","primary":80,"secondary":40,"recfm":"VB","blksize":26000,"lrecl":4096,"volser":"'${VOLUME}'"}'
ADD_EXPORT_DSN_JSON='{"dsorg":"PO","alcunit":"TRK","primary":10,"secondary":5,"dirblk":10,"avgblk":500,"recfm":"FB","blksize":400,"lrecl":80}'
EXPORT_JCL_JSON='{"packagedir":"'${EXPORT}'","jcldataset":"'${EXPORT_DSN}'","workvolume":"'${VOLUME}'"}'
MOUNT_ZOWE_ZFS_JSON='{"action":"mount","mount-point":"'${ZOWE_MOUNT}'","fs-type":"zFS","mode":"rdwr"}'

# URLs 
ADD_SWI_URL="${BASE_URL}/zosmf/swmgmt/swi"
LOAD_PRODUCTS_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${SWI_NAME}/products"
WORKFLOW_DSN_URL="${BASE_URL}/zosmf/restfiles/ds/${WORKFLOW_DSN}"
EXPORT_DSN_URL="${BASE_URL}/zosmf/restfiles/ds/${EXPORT_DSN}"
EXPORT_JCL_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${SWI_NAME}/export"
DELETE_SWI_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${SWI_NAME}"
ACTION_ZOWE_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/${ZOWE_ZFS}"
GET_ZOWE_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs?fsname=${ZOWE_ZFS}"
GET_ZOWE_PATH_URL="${BASE_URL}/zosmf/restfiles/mfs?path=${ZOWE_MOUNT}"
CHECK_WORKFLOW_DSN_URL="${BASE_URL}/zosmf/restfiles/ds?dslevel=${WORKFLOW_DSN}"
CHECK_EXPORT_DSN_URL="${BASE_URL}/zosmf/restfiles/ds?dslevel=${EXPORT_DSN}"

# Check if temp zFS for PSWI is mounted
echo "Checking/mounting ${TMP_ZFS}"
sh scripts/tmp_mounts.sh "${TMP_ZFS}" "${TMP_MOUNT}"
if [ $? -gt 0 ];then exit -1;fi 

if [ "$ZOSMF_V" = "2.3" ]
then
# z/OSMF 2.3

# Check if work zFS for PSWI is mounted
echo "Checking/mounting ${WORK_ZFS}"
sh scripts/tmp_mounts.sh "${WORK_ZFS}" "${WORK_MOUNT}"
if [ $? -gt 0 ];then exit -1;fi 
fi 
  
# Check if ZOWE zFS is mounted
echo "Checking if file system ${ZOWE_ZFS} is mounted."
RESP=`curl -s $GET_ZOWE_ZFS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
MOUNTZ=`echo $RESP | grep -o '"mountpoint":".*"' | cut -f4 -d\"`

if [ -n "$MOUNTZ" ]
then
  # Check if ZOWE zFS is mounted to given ZOWE mountpoint
  if [ "$MOUNTZ/" = "$ZOWE_MOUNT" ]
  then
    echo "${ZOWE_MOUNT} with zFS ${ZOWE_ZFS} mounted will be used."
  else
    echo "The file system ${ZOWE_ZFS} exists but is mounted to different mount point ${MOUNTZ}."
    echo "It is required to have the file system ${ZOWE_ZFS} mounted to the exact mount point (${ZOWE_MOUNT}) to successfully export Zowe PSWI."
    exit -1
  fi
else
  echo "${ZOWE_ZFS} is not mounted anywhere. Checking if ${ZOWE_MOUNT} has any zFS mounted."
  RESP=`curl -s $GET_ZOWE_PATH_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  MOUNTZFS=`echo $RESP | grep -o "name":".*" | cut -f4 -d\"`
  if [ -n "$MOUNTZFS" ]
  then
    # If ZFS is not mounted to the mountpoint then this ZOWE mountpoint has different zFS
    echo "The mountpoint ${ZOWE_MOUNT} has different zFS ${MOUNTZFS}."
    exit -1
  else
  # Mount zFS to Zowe mountpoint
  echo "Mounting zFS ${ZOWE_ZFS} to ${ZOWE_MOUNT} mount point."
  RESP=`curl -s $ACTION_ZOWE_ZFS_URL -k -X "PUT" -d "$MOUNT_ZOWE_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  sh scripts/check_response.sh "${RESP}" $?
  if [ $? -gt 0 ];then exit -1;fi
  fi
fi

# Add workflow to ZOWE data sets
echo "Checking if WORKFLOW data set already exists."

RESP=`curl -s $CHECK_WORKFLOW_DSN_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
DS_COUNT=`echo $RESP | grep -o '"returnedRows":[0-9]*' | cut -f2 -d:`
if [ $DS_COUNT -ne 0 ]
then
  echo "The ${WORKFLOW_DSN} already exist. Because there is a possibility that it contains something unwanted the script does not continue."
  exit -1 
else
  echo "Creating a data set where the post-Deployment workflow will be stored."
  RESP=`curl -s $WORKFLOW_DSN_URL -k -X "POST" -d "$ADD_WORKFLOW_DSN_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  if [ -n "$RESP" ]
  then 
    echo "The creation of the ${WORKFLOW_DSN} was not successful. Error message: ${RESP}"
    exit -1
  fi  
fi

echo "Copying workflows to ${WORKFLOW_DSN} data set."

echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//COPYWRFS EXEC PGM=BPXBATCH" >> JCL
echo "//STDOUT DD SYSOUT=*" >> JCL
echo "//STDERR DD SYSOUT=*" >> JCL
echo "//STDPARM  DD *" >> JCL
echo "SH set -x;set -e;" >> JCL
echo "cd ${WORK_MOUNT};" >> JCL
echo "source=\"${ZOWE_MOUNT}files/workflows/ZWEWRF02.xml\";" >> JCL
echo "target=\"//'${WORKFLOW_DSN}(ZWEWRF02)'\";" >> JCL
echo "iconv -f ISO8859-1 -t IBM-1047 \$source > _ZWEWRF02;" >> JCL
echo "sed 's|UTF-8|IBM-1047|g' _ZWEWRF02 > ZWEWRF02;" >> JCL                         
echo "cp -T ZWEWRF02 \$target;" >> JCL
echo "source=\"${ZOWE_MOUNT}files/workflows/ZWECRECR.xml\";" >> JCL
echo "target=\"//'${WORKFLOW_DSN}(ZWECRECR)'\";" >> JCL
echo "iconv -f ISO8859-1 -t IBM-1047 \$source > _ZWECRECR;" >> JCL
echo "sed 's|UTF-8|IBM-1047|g' _ZWECRECR > ZWECRECR;" >> JCL                         
echo "cp -T ZWECRECR \$target;" >> JCL
echo "source=\"${ZOWE_MOUNT}files/workflows/ZWEKRING.xml\";" >> JCL
echo "target=\"//'${WORKFLOW_DSN}(ZWEKRING)'\";" >> JCL
echo "iconv -f ISO8859-1 -t IBM-1047 \$source > _ZWEKRING;" >> JCL
echo "sed 's|UTF-8|IBM-1047|g' _ZWEKRING > ZWEKRING;" >> JCL                         
echo "cp -T ZWEKRING \$target;" >> JCL
echo "source=\"${ZOWE_MOUNT}files/workflows/ZWELOADC.xml\";" >> JCL
echo "target=\"//'${WORKFLOW_DSN}(ZWELOADC)'\";" >> JCL
echo "iconv -f ISO8859-1 -t IBM-1047 \$source > _ZWELOADC;" >> JCL
echo "sed 's|UTF-8|IBM-1047|g' _ZWELOADC > ZWELOADC;" >> JCL                         
echo "cp -T ZWELOADC \$target;" >> JCL
echo "source=\"${ZOWE_MOUNT}files/workflows/ZWESIGNC.xml\";" >> JCL
echo "target=\"//'${WORKFLOW_DSN}(ZWESIGNC)'\";" >> JCL
echo "iconv -f ISO8859-1 -t IBM-1047 \$source > _ZWESIGNC;" >> JCL
echo "sed 's|UTF-8|IBM-1047|g' _ZWESIGNC > ZWESIGNC;" >> JCL                         
echo "cp -T ZWESIGNC \$target;" >> JCL
echo "source=\"${ZOWE_MOUNT}files/workflows/ZWECONF.xml\";" >> JCL
echo "target=\"//'${WORKFLOW_DSN}(ZWECONF)'\";" >> JCL
echo "iconv -f ISO8859-1 -t IBM-1047 \$source > _ZWECONF;" >> JCL
echo "sed 's|UTF-8|IBM-1047|g' _ZWECONF > ZWECONF;" >> JCL                         
echo "cp -T ZWECONF \$target;" >> JCL
echo "/*" >> JCL

sh scripts/submit_jcl.sh "`cat JCL`"
if [ $? -gt 0 ];then exit -1;fi
rm JCL

# Add data set for export jobs
echo "Checking if the data set for export jobs already exists."

RESP=`curl -s $CHECK_EXPORT_DSN_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
DSN_COUNT=`echo $RESP | grep -o '"returnedRows":[0-9]*' | cut -f2 -d:`
if [ $DSN_COUNT -ne 0 ]
then
  echo "The ${EXPORT_DSN} already exist. Because there is a possibility that it contains something unwanted the script does not continue."
  exit -1
else
  echo "Creating a data set where the export jobs will be stored."
  RESP=`curl -s $EXPORT_DSN_URL -k -X "POST" -d "$ADD_EXPORT_DSN_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  if [ -n "$RESP" ]
  then echo "The creation of the ${EXPORT_DSN} was not successful. Error message: ${RESP}"
  fi  
fi

# Delete Software instance if it already exists
# No check of return code because if it does not exist the script would fail (return code 404)
echo 'Invoking REST API to delete the software instance if the previous test did not delete it.'

curl -s $DELETE_SWI_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS

# Add Software Instance
echo 'Invoking REST API to add a Software Instance.'

RESP=`curl -s $ADD_SWI_URL -k -X "POST" -d "$ADD_SWI_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
if [ $? -gt 0 ];then exit -1;fi

# Load the products, features, and FMIDs for a software instance
# The response is in format "statusurl":"https:\/\/:ZOSMF_URL:post\/restofurl"
# On statusurl can be checked actual status of loading the products, features, and FMIDs
echo 'Invoking REST API to load SMP/E managed products from the SMP/E CSI.'


RESP=`curl -s $LOAD_PRODUCTS_URL -k -X "PUT" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
if [ $? -gt 0 ];then exit -1;fi

LOAD_STATUS_URL=`echo $RESP | grep -o '"statusurl":".*"' | cut -f4 -d\" | tr -d '\' 2>/dev/null`
if [ -z "$LOAD_STATUS_URL" ]
then
  echo "No response from the REST API call."
  exit -1
fi

# Check the actual status of loading the products until the status is not "complete"
echo 'Invoking REST API to check if load products has finished.'

STATUS=""
until [ "$STATUS" = "complete" ]
do
RESP=`curl -s $LOAD_STATUS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
if [ $? -gt 0 ];then exit -1;fi
STATUS=`echo $RESP | grep -o '"status":".*"' | cut -f4 -d\"`
sleep 3   
done

echo "Load Products finished successfully."


# Create JCL that will export Portable Software Instance
# The response is in format "statusurl":"https:\/\/:ZOSMF_URL:post\/restofurl"
echo 'Invoking REST API to export the software instance.'

RESP=`curl -s $EXPORT_JCL_URL -k -X "POST" -d "$EXPORT_JCL_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS `
sh scripts/check_response.sh "${RESP}" $?
if [ $? -gt 0 ];then exit -1;fi
EXPORT_STATUS_URL=`echo $RESP | grep -o '"statusurl":".*"' | cut -f4 -d\" | tr -d '\' 2>/dev/null`
if [ -z "$EXPORT_STATUS_URL" ]
then
  echo "No response from the REST API call."
  exit -1
fi

# Check the actual status of generating JCL until the status is not "complete"
echo 'Invoking REST API to check if export has finished.'

STATUS=""
until [ "$STATUS" = "complete" ]
do
# Status is not shown until the recentage is not 100 
RESP=`curl -s $EXPORT_STATUS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
if [ $? -gt 0 ];then exit -1;fi
PERCENTAGE=`echo ${RESP} | grep -o '"percentcomplete":".*"' | cut -f4 -d\"`

echo ${PERCENTAGE} "% of the Export JCL created."

if [ "$PERCENTAGE" = "100" ]
then
  STATUS=`echo $RESP | grep -o '"status":".*"' | cut -f4 -d\"`
  DSN=`echo $RESP | grep -o '"jcl":.*\]' | cut -f4 -d\"`

  echo "The status is: "$STATUS
  # Can be 100% but still running
  if [ "$STATUS" != "complete" ] && [ "$STATUS" != "running" ]
  then
    echo "Status of generation of Export JCL failed."
    exit -1
  fi
fi
sleep 3
done

if [ -z "$DSN" ]
then
  echo "The creation of export JCL failed"
  exit -1
fi

echo "Downloading export JCL"
curl -s ${BASE_URL}/zosmf/restfiles/ds/${DSN} -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS > EXPORT

if [ "$ZOSMF_V" = "2.3" ]
then
echo "Changing jobcard and adding SYSAFF"
sed "s|//IZUD01EX JOB (ACCOUNT),'NAME'|$JOBST1\n$JOBST2|g" EXPORT > EXPJCL0

echo "Changing working directory from /tmp/ to ${WORK_MOUNT} directory where is zFS mounted"
sed "s|//SMPWKDIR DD PATH='/tmp/.*'|//SMPWKDIR DD PATH='$WORK_MOUNT'|g" EXPJCL0 > EXPJCL1

echo "Switching WORKFLOW and CSI datasets because of internal GIMZIP setting" # It is not working when CSI is in the beginning (1st or 2nd)
sed "s|\.CSI|\.1WORKFLOW|g" EXPJCL1 > EXPJCL2
sed "s|\.WORKFLOW|\.CSI|g" EXPJCL2 > EXPJCL3
sed "s|\.1WORKFLOW|\.WORKFLOW|g" EXPJCL3 > EXPJCL4
sed "s|DSNTYPE=LARGE|DSNTYPE=LARGE,VOL=SER=$VOLUME|g" EXPJCL4 > EXPJCL

rm ./EXPJCL0
rm ./EXPJCL1
rm ./EXPJCL2
rm ./EXPJCL3
rm ./EXPJCL4

else
echo "Changing jobcard and adding SYSAFF"
sed "s|//IZUD01EX JOB (ACCOUNT),'NAME'|$JOBST1\n$JOBST2|g" EXPORT > EXPJCL 
fi

sh scripts/submit_jcl.sh "`cat EXPJCL`"
if [ $? -gt 0 ];then exit -1;fi

rm ./EXPJCL
rm ./EXPORT

# Pax the directory 
echo "PAXing the final PSWI."

echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//PAXDIREC EXEC PGM=BPXBATCH" >> JCL
echo "//STDOUT DD SYSOUT=*" >> JCL
echo "//STDERR DD SYSOUT=*" >> JCL
echo "//STDPARM  DD *" >> JCL
echo "SH set -x;set -e;" >> JCL
echo "cd ${EXPORT};" >> JCL
echo "pax -wv -f ${TMP_MOUNT}/${SWI_NAME}.pax.Z ." >> JCL
echo "/*" >> JCL

sh scripts/submit_jcl.sh "`cat JCL`"
if [ $? -gt 0 ];then exit -1;fi
rm JCL

cd ../.pax
sshpass -p${ZOSMF_PASS} sftp -o HostKeyAlgorithms=+ssh-rsa -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${TMP_MOUNT}
get ${SWI_NAME}.pax.Z
EOF
cd ../pswi

#TODO: redirect everything to $log/x ? 
#TODO: Check why there is name in mountpoints responses and it still doesn't show (although the mount points are different so it's good it is not doing anything)                      
