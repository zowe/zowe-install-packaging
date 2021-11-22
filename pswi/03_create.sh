#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
MOUNTED=false
WMOUNTED=false
OMOUNTED=false

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
echo "Storage Class      :" $STORCLAS
echo "ACCOUNT            :" $ACCOUNT
echo "SYSAFF             :" $SYSAFF
echo "z/OSMF version     :" $ZOSMF_V

# JSONs      
ADD_SWI_JSON='{"name":"'${SWI_NAME}'","system":"'${ZOSMF_SYSTEM}'","description":"ZOWE v'${VERSION}' Portable Software Instance",
"globalzone":"'${GLOBAL_ZONE}'","targetzones":["'${ZONE}'"],"workflows":[{"name":"ZOWE Mount Workflow","description":"This workflow performs mount action of ZOWE zFS.",
"location": {"dsname":"'${WORKFLOW_DSN}'(ZWE9MNT)"}}],"products":[{"prodname":"ZOWE","release":"'${VERSION}'","vendor":"Open Mainframe Project","url":"https://www.zowe.org/"}]}'
if [ -n "$STORCLAS" ] # there has to be either STORCLAS or VOLUME
then
  ADD_WORKFLOW_DSN_JSON='{"dirblk":5,"avgblk":25000,"dsorg":"PO","alcunit":"TRK","primary":80,"secondary":40,"recfm":"VB","blksize":26000,"lrecl":4096,"storclass":"'${STORCLAS}'"}'
else
  ADD_WORKFLOW_DSN_JSON='{"dirblk":5,"avgblk":25000,"dsorg":"PO","alcunit":"TRK","primary":80,"secondary":40,"recfm":"VB","blksize":26000,"lrecl":4096,"volser":"'${VOLUME}'"}'
fi
ADD_EXPORT_DSN_JSON='{"dsorg":"PO","alcunit":"TRK","primary":10,"secondary":5,"dirblk":10,"avgblk":500,"recfm":"FB","blksize":400,"lrecl":80}'
if [ -n "$STORCLAS" ] # there has to be either STORCLAS or VOLUME
then
  EXPORT_JCL_JSON='{"packagedir":"'${EXPORT}'","jcldataset":"'${EXPORT_DSN}'","workstorclas":"'${STORCLAS}'"}'
else
  EXPORT_JCL_JSON='{"packagedir":"'${EXPORT}'","jcldataset":"'${EXPORT_DSN}'","workvolume":"'${VOLUME}'"}'
fi
if [ -n "$STORCLAS" ] # there has to be either STORCLAS or VOLUME
then
  NEW_ZFS_JSON='{"cylsPri":1160,"cylsSec": 116,"storageClass":"'${STORCLAS}'"}'
else
  NEW_ZFS_JSON='{"cylsPri":1160,"cylsSec": 116,"volumes":[ "'${VOLUME}'" ]}'
fi
MOUNT_ZOWE_ZFS_JSON='{"action":"mount","mount-point":"'${ZOWE_MOUNT}'","fs-type":"zFS","mode":"rdwr"}'

# URLs 
ADD_SWI_URL="${BASE_URL}/zosmf/swmgmt/swi"
LOAD_PRODUCTS_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${SWI_NAME}/products"
WORKFLOW_DSN_URL="${BASE_URL}/zosmf/restfiles/ds/${WORKFLOW_DSN}"
EXPORT_DSN_URL="${BASE_URL}/zosmf/restfiles/ds/${EXPORT_DSN}"
EXPORT_JCL_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${SWI_NAME}/export"
SUBMIT_JOB_URL="${BASE_URL}/zosmf/restjobs/jobs"
NEW_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/zfs/${TMP_ZFS}"
NEW_WORK_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/zfs/${WORK_ZFS}"
NEW_OUTPUT_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/zfs/${OUTPUT_ZFS}"
DELETE_SWI_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${SWI_NAME}"
ACTION_ZOWE_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/${ZOWE_ZFS}"
GET_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs?fsname=${TMP_ZFS}"
GET_WORK_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs?fsname=${WORK_ZFS}"
GET_OUTPUT_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs?fsname=${OUTPUT_ZFS}"
GET_ZOWE_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs?fsname=${ZOWE_ZFS}"
GET_PATH_URL="${BASE_URL}/zosmf/restfiles/mfs?path=${TMP_MOUNT}"
GET_WORK_PATH_URL="${BASE_URL}/zosmf/restfiles/mfs?path=${WORK_MOUNT}"
GET_OUTPUT_PATH_URL="${BASE_URL}/zosmf/restfiles/mfs?path=${OUTPUT_MOUNT}"
GET_ZOWE_PATH_URL="${BASE_URL}/zosmf/restfiles/mfs?path=${ZOWE_MOUNT}"
CHECK_ZFS_URL="${BASE_URL}/zosmf/restfiles/ds?dslevel=${TMP_ZFS}"
CHECK_WORK_ZFS_URL="${BASE_URL}/zosmf/restfiles/ds?dslevel=${WORK_ZFS}"
CHECK_OUTPUT_ZFS_URL="${BASE_URL}/zosmf/restfiles/ds?dslevel=${OUTPUT_ZFS}"
CHECK_WORKFLOW_DSN_URL="${BASE_URL}/zosmf/restfiles/ds?dslevel=${WORKFLOW_DSN}"
CHECK_EXPORT_DSN_URL="${BASE_URL}/zosmf/restfiles/ds?dslevel=${EXPORT_DSN}"

# Check if temp zFS for PSWI is mounted
echo "Checking if temporary file system ${TMP_ZFS} is mounted."
RESP=`curl -s $GET_ZFS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
MOUNTP=`echo $RESP | grep -o '"mountpoint":".*"' | cut -f4 -d\"`

if [ -n "$MOUNTP" ]
then
  # Check if temp zFS is mounted to given mount point
  if [ "$MOUNTP" = "$TMP_MOUNT" ]
  then
    echo "${TMP_MOUNT} with zFS ${TMP_ZFS} mounted will be used as is."
    MOUNTED=true
  else
    echo "The file system ${TMP_ZFS} exists but is mounted to different mount point(${MOUNTP})."
    echo "Use different name of zFS or ${MOUNTP} for mount point."
    exit -1
  fi
else
  echo "Temporary zFS isn't mounted. Now checking if mount point has any other zFS mounted."
  RESP=`curl -s $GET_PATH_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  sh scripts/check_response.sh "${RESP}" $?
  if [ $? -gt 0 ];then exit -1;fi 
  MOUNTZFS=`echo $RESP | grep -o "name":".*" | cut -f4 -d\"`
  if [ -n "$MOUNTZFS" ]
  then
    # If zFS is not mounted to the mount point then this mount point has different zFS
    echo "The mount point ${TMP_MOUNT} has different zFS (${MOUNTZFS}) mounted."
    echo "Use different mount point (not ${TMP_MOUNT})."
    echo "Or use ${MOUNTZFS} for zFS."
    exit -1
  fi
fi


if [ "$MOUNTED" = false ]
then
  # Check if data set exists
  echo "Checking if temporary zFS ${TMP_ZFS} exists."
  RESP=`curl -s $CHECK_ZFS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  sh scripts/check_response.sh "${RESP}" $?
  if [ $? -gt 0 ];then exit -1;fi
  ZFS_COUNT=`echo $RESP | grep -o '"returnedRows":[0-9]*' | cut -f2 -d:`
  if [ "$ZFS_COUNT" = "0" ]
  then
    # Create new zFS if not
    echo "${TMP_ZFS} does not exists."
    echo "Creating new zFS ${TMP_ZFS}."
    RESP=`curl -s $NEW_ZFS_URL -k -X "POST" -d "$NEW_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
    sh scripts/check_response.sh "${RESP}" $?
    if [ $? -gt 0 ];then exit -1;fi
  else
    #TODO: also check the first dsname because it can be something that just has tmp_zfs as HLQ
    echo
  fi
  # Mount zFS to TMP_MOUNT
  echo "Mounting zFS ${TMP_ZFS} to ${TMP_MOUNT} mount point with JCL because REST API doesn't allow AGGRGROW parm."

echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//MKDIR  EXEC PGM=BPXBATCH" >> JCL
echo "//STDOUT DD SYSOUT=*" >> JCL
echo "//STDERR DD SYSOUT=*" >> JCL
echo "//STDPARM  DD *" >> JCL
echo "SH mkdir -p ${TMP_MOUNT}" >> JCL
echo "/*" >> JCL
echo "//MNT1ZFS1 EXEC PGM=IKJEFT01,REGION=4096K,DYNAMNBR=50" >> JCL
echo "//SYSTSPRT DD SYSOUT=*" >> JCL
echo "//SYSTSOUT DD SYSOUT=*" >> JCL
echo "//SYSTSIN DD * " >> JCL
echo "MOUNT FILESYSTEM('${TMP_ZFS}') +  " >> JCL
echo "TYPE(ZFS) MODE(RDWR) +     " >> JCL
echo "PARM('AGGRGROW') +   " >> JCL                  
echo "MOUNTPOINT('${TMP_MOUNT}')    " >> JCL                    
echo "/*" >> JCL

  sh scripts/submit_jcl.sh "`cat JCL`"
  if [ $? -gt 0 ];then exit -1;fi
  rm JCL
fi

if [ "$ZOSMF_V" = "2.3" ]
then
# z/OSMF 2.3

# Check if work zFS for PSWI is mounted
echo "Checking if work file system ${WORK_ZFS} is mounted."
RESP=`curl -s $GET_WORK_ZFS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
WMOUNTP=`echo $RESP | grep -o '"mountpoint":".*"' | cut -f4 -d\"`

if [  -n "$WMOUNTP" ]
then
  # Check if temp zFS is mounted to given mount point
  if [ "$WMOUNTP" = "$WORK_MOUNT" ]
  then
    echo "${WORK_MOUNT} with work zFS ${WORK_ZFS} mounted will be used as is."
    WMOUNTED=true
  else
    echo "The file system ${WORK_ZFS} exists but is mounted to different mount point(${WMOUNTP})."
    echo "Use different name of zFS or ${WMOUNTP} for mount point."
    exit -1
  fi
else
  echo "Work zFS isn't mounted. Now checking if mount point has any other zFS mounted."
  RESP=`curl -s $GET_WORK_PATH_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  sh scripts/check_response.sh "${RESP}" $?
  if [ $? -gt 0 ];then exit -1;fi 
  WMOUNTZFS=`echo $RESP | grep -o "name":".*" | cut -f4 -d\"`
  if [ -n "$WMOUNTZFS" ]
  then
    # If zFS is not mounted to the mount point then this mount point has different zFS
    echo "The mount point ${WORK_MOUNT} has different zFS (${WMOUNTZFS}) mounted."
    echo "Use different mount point (not ${WORK_MOUNT})."
    echo "Or use ${WMOUNTZFS} for zFS."
    exit -1
  fi
fi


if [ "$WMOUNTED" = false ]
then
  # Check if data set exists
  echo "Checking if temporary zFS ${WORK_ZFS} exists."
  RESP=`curl -s $CHECK_WORK_ZFS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  sh scripts/check_response.sh "${RESP}" $?
  if [ $? -gt 0 ];then exit -1;fi
  WZFS_COUNT=`echo $RESP | grep -o '"returnedRows":[0-9]*' | cut -f2 -d:`
  if [ "$WZFS_COUNT" = "0" ]
  then
    # Create new zFS if not
    echo "${WORK_ZFS} does not exists."
    echo "Creating new zFS ${WORK_ZFS}."
    RESP=`curl -s $NEW_WORK_ZFS_URL -k -X "POST" -d "$NEW_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
    sh scripts/check_response.sh "${RESP}" $?
    if [ $? -gt 0 ];then exit -1;fi
  else
    #TODO: also check the first dsname because it can be something that just has tmp_zfs as HLQ
    echo
  fi
  # Mount zFS to TMP_MOUNT with JCL because REST API doesn't allow AGGRGROW parm
  echo "Mounting zFS ${WORK_ZFS} to ${WORK_MOUNT} mount point"
  
echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//MKDIR  EXEC PGM=BPXBATCH" >> JCL
echo "//STDOUT DD SYSOUT=*" >> JCL
echo "//STDERR DD SYSOUT=*" >> JCL
echo "//STDPARM  DD *" >> JCL
echo "SH mkdir -p ${WORK_MOUNT}" >> JCL
echo "/*" >> JCL
echo "//MNT1ZFS1 EXEC PGM=IKJEFT01,REGION=4096K,DYNAMNBR=50" >> JCL
echo "//SYSTSPRT DD SYSOUT=*" >> JCL
echo "//SYSTSOUT DD SYSOUT=*" >> JCL
echo "//SYSTSIN DD * " >> JCL
echo "MOUNT FILESYSTEM('${WORK_ZFS}') +  " >> JCL
echo "TYPE(ZFS) MODE(RDWR) +     " >> JCL
echo "PARM('AGGRGROW') +   " >> JCL                  
echo "MOUNTPOINT('${WORK_MOUNT}')    " >> JCL                    
echo "/*" >> JCL

  sh scripts/submit_jcl.sh "`cat JCL`"
  if [ $? -gt 0 ];then exit -1;fi
  rm JCL
fi
fi 


# Check if output zFS for PSWI is mounted
echo "Checking if output file system ${OUTPUT_ZFS} is mounted."
RESP=`curl -s $GET_OUTPUT_ZFS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
MOUNTO=`echo $RESP | grep -o '"mountpoint":".*"' | cut -f4 -d\"`

if [ -n "$MOUNTO" ]
then
  # Check if output zFS is mounted to given mount point
  if [ "$MOUNTO" = "$OUTPUT_MOUNT" ]
  then
    echo "${OUTPUT_MOUNT} with zFS ${OUTPUT_ZFS} mounted will be used as is."
    OMOUNTED=true
  else
    echo "The file system ${OUTPUT_ZFS} exists but is mounted to different mount point(${MOUNTO})."
    echo "Use different name of zFS or ${MOUNTO} for mount point."
    exit -1
  fi
else
  echo "Temporary zFS isn't mounted. Now checking if mount point has any other zFS mounted."
  RESP=`curl -s $GET_OUTPUT_PATH_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  sh scripts/check_response.sh "${RESP}" $?
  if [ $? -gt 0 ];then exit -1;fi 
  MOUNTOZFS=`echo $RESP | grep -o "name":".*" | cut -f4 -d\"`
  if [ -n "$MOUNTOZFS" ]
  then
    # If zFS is not mounted to the mount point then this mount point has different zFS
    echo "The mount point ${OUTPUT_ZFS} has different zFS (${MOUNTOZFS}) mounted."
    echo "Use different mount point (not ${OUTPUT_MOUNT})."
    echo "Or use ${MOUNTOZFS} for zFS."
    exit -1
  fi
fi


if [ "$OMOUNTED" = false ]
then
  # Check if data set exists
  echo "Checking if temporary zFS ${OUTPUT_ZFS} exists."
  RESP=`curl -s $CHECK_OUTPUT_ZFS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  sh scripts/check_response.sh "${RESP}" $?
  if [ $? -gt 0 ];then exit -1;fi
  OUTPUT_ZFS_COUNT=`echo $RESP | grep -o '"returnedRows":[0-9]*' | cut -f2 -d:`
  if [ "$OUTPUT_ZFS_COUNT" = "0" ]
  then
    # Create new zFS if not
    echo "${OUTPUT_ZFS} does not exists."
    echo "Creating new zFS ${OUTPUT_ZFS}."
    RESP=`curl -s $NEW_OUTPUT_ZFS_URL -k -X "POST" -d "$NEW_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
    sh scripts/check_response.sh "${RESP}" $?
    if [ $? -gt 0 ];then exit -1;fi
  else
    #TODO: also check the first dsname because it can be something that just has tmp_zfs as HLQ
    echo
  fi
  # Mount zFS to OUTPUT_MOUNT
  echo "Mounting zFS ${OUTPUT_ZFS} to ${OUTPUT_MOUNT} mount point with JCL because REST API doesn't allow AGGRGROW parm."
  
echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//MKDIR  EXEC PGM=BPXBATCH" >> JCL
echo "//STDOUT DD SYSOUT=*" >> JCL
echo "//STDERR DD SYSOUT=*" >> JCL
echo "//STDPARM  DD *" >> JCL
echo "SH mkdir -p ${OUTPUT_MOUNT}" >> JCL
echo "/*" >> JCL
echo "//MNT1ZFS1 EXEC PGM=IKJEFT01,REGION=4096K,DYNAMNBR=50" >> JCL
echo "//SYSTSPRT DD SYSOUT=*" >> JCL
echo "//SYSTSOUT DD SYSOUT=*" >> JCL
echo "//SYSTSIN DD * " >> JCL
echo "MOUNT FILESYSTEM('${OUTPUT_ZFS}') +  " >> JCL
echo "TYPE(ZFS) MODE(RDWR) +     " >> JCL
echo "PARM('AGGRGROW') +   " >> JCL                  
echo "MOUNTPOINT('${OUTPUT_MOUNT}')    " >> JCL                    
echo "/*" >> JCL

  sh scripts/submit_jcl.sh "`cat JCL`"
  if [ $? -gt 0 ];then exit -1;fi
  rm JCL
fi

echo "Deleting PAX files from ${OUTPUT_MOUNT} if there are any."

echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//MKDIR  EXEC PGM=BPXBATCH" >> JCL
echo "//STDOUT DD SYSOUT=*" >> JCL
echo "//STDERR DD SYSOUT=*" >> JCL
echo "//STDPARM  DD *" >> JCL
echo "SH cd ${OUTPUT_MOUNT};" >> JCL
echo "rm *.pax.Z" >> JCL
echo "/*" >> JCL

  sh scripts/submit_jcl.sh "`cat JCL`"
  rm JCL
  
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

# Store ZWE9MNT wokflow in the WORKFLOW dataset
echo "Uploading workflow ZWE9MNT into ${DIR} directory thru SSH"

cd workflows
HOST=${ZOSMF_URL#https:\/\/}

sshpass -p${ZOSMF_PASS} sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${DIR}
put ZWE9MNT
EOF
cd ..
#TODO: copy workflows to WORKFLOW_DSN data set

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

sshpass -p${ZOSMF_PASS} sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${EXPORT}
pax -wv -f ${OUTPUT_MOUNT}/${SWI_NAME}-${VERSION}.pax.Z .
EOF
if [ $? -gt 0 ];then exit -1;fi



#TODO: send e-mail that PSWI is ready in the output mount?
#TODO: redirect everything to $log/x ? 
#TODO: Check why there is name in mountpoints responses and it still doesn't show (although the mount points are different so it's good it is not doing anything)                      
