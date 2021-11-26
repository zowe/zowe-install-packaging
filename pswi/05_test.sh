#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
MOUNTED=false
WMOUNTED=false
OMOUNTED=false

echo ""
echo ""
echo "Script for testing a Portable Software Instance..."
echo "Host                   :" $ZOSMF_URL
echo "Port                   :" $ZOSMF_PORT
echo "PSWI name              :" $PSWI
echo "z/OSMF system          :" $ZOSMF_SYSTEM
echo "Test HLQ               :" $TEST_HLQ
echo "Test mount point       :" $TEST_MOUNT
echo "Job name               :" $JOBNAME
echo "Deploy name            :" $DEPLOY_NAME
echo "Software instance name :" $DEPLOY_NAME 
echo "Temporary directory    :" $TMP_MOUNT
echo "Temporary zFS          :" $TMP_ZFS
echo "Work zFS               :" $WORK_ZFS # For z/OSMF v2.3
echo "Work mount point       :" $WORK_MOUNT # For z/OSMF v2.3
echo "Storage Class          :" $STORCLAS
echo "Volume                 :" $VOLUME
echo "ACCOUNT                :" $ACCOUNT
echo "SYSAFF                 :" $SYSAFF
echo "z/OSMF version         :" $ZOSMF_V

if [ -n "$STORCLAS" ] # there has to be either STORCLAS or VOLUME
then
  NEW_ZFS_JSON='{"cylsPri":1160,"cylsSec": 116,"storageClass":"'${STORCLAS}'"}'
else
  NEW_ZFS_JSON='{"cylsPri":1160,"cylsSec": 116,"volumes":[ "'${VOLUME}'" ]}'
fi
NEW_PSWI_JSON='{"name":"'${PSWI}'","system":"'${ZOSMF_SYSTEM}'","description":"Zowe PSWI for testing","directory":"'${EXPORT}'"}'
NEW_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/zfs/${TMP_ZFS}"
NEW_WORK_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/zfs/${WORK_ZFS}"
NEW_OUTPUT_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/zfs/${OUTPUT_ZFS}"
GET_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs?fsname=${TMP_ZFS}"
GET_WORK_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs?fsname=${WORK_ZFS}"
GET_OUTPUT_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs?fsname=${OUTPUT_ZFS}"
GET_PATH_URL="${BASE_URL}/zosmf/restfiles/mfs?path=${TMP_MOUNT}"
GET_WORK_PATH_URL="${BASE_URL}/zosmf/restfiles/mfs?path=${WORK_MOUNT}"
GET_OUTPUT_PATH_URL="${BASE_URL}/zosmf/restfiles/mfs?path=${OUTPUT_MOUNT}"
CHECK_ZFS_URL="${BASE_URL}/zosmf/restfiles/ds?dslevel=${TMP_ZFS}"
CHECK_WORK_ZFS_URL="${BASE_URL}/zosmf/restfiles/ds?dslevel=${WORK_ZFS}"
CHECK_OUTPUT_ZFS_URL="${BASE_URL}/zosmf/restfiles/ds?dslevel=${OUTPUT_ZFS}"

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
  # Mount zFS to TMP_MOUNT with JCL because REST API doesn't allow AGGRGROW parm
  echo "Mounting zFS ${TMP_ZFS} to ${TMP_MOUNT} mount point with JCL."
  
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

# Check if output zFS for PSWI is mounted
echo "Checking if output file system ${OUTPUT_ZFS} is still mounted."
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
  if [-n "$MOUNTOZFS" ]
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

# Unpax the directory (create directory for test_mount)
echo "UnPAXing the final PSWI."

echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//UNPAXDIR EXEC PGM=BPXBATCH" >> JCL
echo "//STDOUT DD SYSOUT=*" >> JCL
echo "//STDERR DD SYSOUT=*" >> JCL
echo "//STDPARM  DD *" >> JCL
echo "SH mkdir -p ${TEST_MOUNT};" >> JCL
echo "mkdir -p ${EXPORT};" >> JCL
echo "cd ${EXPORT};" >> JCL
echo "pax -rv -f ${OUTPUT_MOUNT}/${SWI_NAME}-${VERSION}.pax.Z" >> JCL
echo "/*" >> JCL

sh scripts/submit_jcl.sh "`cat JCL`"
if [ $? -gt 0 ];then exit -1;fi
rm JCL


if [ "$ZOSMF_V" = "2.4" ]; then
  echo "Not covering deployment on z/OSMF 2.4 yet."
# z/OSMF 2.4

# Delete Portable Software Instance if it already exists
# No check of return code because if it does not exist the script would fail (return code 404)
#echo 'Invoking REST API to delete the portable software instance if the previous test did not delete it.'
#
#RESP=`curl -s ${BASE_URL}/zosmf/swmgmt/pswi/${ZOSMF_SYSTEM}/${PSWI} -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS `
#
## The response is in format "statusurl":"https:\/\/:ZOSMF_URL:post\/restofurl"
#echo 'Invoking REST API to register a Portable Software Instance'
#
#RESP=`curl -s ${BASE_URL}/zosmf/swmgmt/pswi -k -X "POST" -d "$NEW_PSWI_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS `
#sh scripts/check_response.sh "${RESP}" $?
#if [ $? -gt 0 ];then exit -1;fi
#
#EXPORT_STATUS_URL=`echo $RESP | grep -o '"statusurl":".*"' | cut -f4 -d\" | tr -d '\' 2>/dev/null`
#if [ "$EXPORT_STATUS_URL" == "" ]
#then
#  echo "No response from the REST API call."
#  exit -1
#fi
#
#STATUS=""
#until [ "$STATUS" == "complete" ]
#do
#RESP=`curl -s $EXPORT_STATUS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
#sh scripts/check_response.sh "${RESP}" $?
#if [ $? -gt 0 ];then exit -1;fi
#
#STATUS=`echo $RESP | grep -o '"status":".*"' | cut -f4 -d\"`
#echo "The status is: "$STATUS
#
#if [ "$STATUS" != "complete" ] && [ "$STATUS" != "running" ]
#then
#  echo "Registration of PSWI in z/OSMF failed."
#  exit -1
#fi
#sleep 3
#done
#
#google-chrome --version
#RC=$?
#
#if [ $RC -gt 0 ];
#then
#echo "Checking if the system is CentOS or RHEL."
#yum version
#RC=$?
#
#if [ $RC -gt 0 ];
#then 
#  echo "Installing Chrome on Debian/Ubuntu."
#  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
#  sudo apt-get install ./google-chrome-stable_current_*.rpm
#else 
#  echo "Installing Chrome on CentOS or RHEL."
#  wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
#  sudo yum install ./google-chrome-stable_current_*.rpm
#fi
#fi
#
#echo "Downloading Chromedriver"
#version=`google-chrome --product-version`
#url="https://chromedriver.storage.googleapis.com/"${version}"/chromedriver_linux64.zip"
#rm chromedriver.zip
#rm chromedriver
#wget $url -nc -O chromedriver.zip
#
## Run the deployment test
#echo " Running the deployment test for z/OSMF version 2.4"
#DIR=`pwd`
#PATH=$DIR/scripts/spool_files.sh:$PATH
#pip install selenium
#pip install requests
#
#export HEADLESS="true"
#python ../PSI_testing/deploy_test.py
#
#rm chromedriver

else
# z/OSMF 2.3

# Check if work zFS for PSWI is mounted
echo "Checking if work file system ${WORK_ZFS} is mounted."
RESP=`curl -s $GET_WORK_ZFS_URL -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
WMOUNTP=`echo $RESP | grep -o '"mountpoint":".*"' | cut -f4 -d\"`

if [ -n "$WMOUNTP" ]
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
  # Mount zFS to WORK_MOUNT with JCL because REST API doesn't allow AGGRGROW parm
  echo "Mounting zFS ${WORK_ZFS} to ${WORK_MOUNT} mount point."
  
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

# Run the deployment test
echo " Running the deployment test for z/OSMF version 2.3"

pip install requests
python scripts/deploy_test_2_3.py

fi
