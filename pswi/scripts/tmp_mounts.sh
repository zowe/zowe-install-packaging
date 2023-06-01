#!/bin/sh
#version=1.0

ZFS=${1}
MOUNT=${2}
MOUNTED=false

echo "Checking if file system ${ZFS} is mounted."
RESP=`curl -s "${BASE_URL}/zosmf/restfiles/mfs?fsname=${ZFS}" -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
MOUNTP=`echo $RESP | grep -o '"mountpoint":".*"' | cut -f4 -d\"`

NEW_ZFS_JSON='{"cylsPri":2000,"cylsSec": 140,"volumes":[ "'${VOLUME}'" ]}'
 
  
if [ -n "$MOUNTP" ]
then
  # Check if temp zFS is mounted to given mount point
  if [ "$MOUNTP" = "$MOUNT" ]
  then
    echo "${MOUNT} with zFS ${ZFS} mounted will be used as is."
    MOUNTED=true
  else
    echo "The file system ${ZFS} exists but is mounted to different mount point(${MOUNTP})."
    echo "Use different name of zFS or ${MOUNTP} for mount point."
    exit -1
  fi
else
  echo "Temporary zFS isn't mounted. Now checking if mount point has any other zFS mounted."
  RESP=`curl -s "${BASE_URL}/zosmf/restfiles/mfs?path=${MOUNT}" -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  sh scripts/check_response.sh "${RESP}" $?
  if [ $? -gt 0 ];then exit -1;fi 
  MOUNTZFS=`echo $RESP | grep -o "name":".*" | cut -f4 -d\"`
  if [ -n "$MOUNTZFS" ]
  then
    # If zFS is not mounted to the mount point then this mount point has different zFS
    echo "The mount point ${MOUNT} has different zFS (${MOUNTZFS}) mounted."
    echo "Use different mount point (not ${MOUNT})."
    echo "Or use ${MOUNTZFS} for zFS."
    exit -1
  fi
fi


if [ "$MOUNTED" = false ]
then
  # Check if data set exists
  echo "Checking if temporary zFS ${TMP_ZFS} exists."
  RESP=`curl -s "${BASE_URL}/zosmf/restfiles/ds?dslevel=${ZFS}" -k -X "GET" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
  sh scripts/check_response.sh "${RESP}" $?
  if [ $? -gt 0 ];then exit -1;fi
  ZFS_COUNT=`echo $RESP | grep -o '"returnedRows":[0-9]*' | cut -f2 -d:`
  if [ "$ZFS_COUNT" = "0" ]
  then
    # Create new zFS if not
    echo "${ZFS} does not exists."
    echo "Creating new zFS ${ZFS}."
    RESP=`curl -s "${BASE_URL}/zosmf/restfiles/mfs/zfs/${ZFS}" -k -X "POST" -d "$NEW_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
    sh scripts/check_response.sh "${RESP}" $?
    if [ $? -gt 0 ];then exit -1;fi
  else
    #TODO: also check the first dsname because it can be something that just has tmp_zfs as HLQ
    echo
  fi
  # Mount zFS to TMP_MOUNT
  echo "Mounting zFS ${ZFS} to ${MOUNT} mount point with JCL because REST API doesn't allow AGGRGROW parm."

echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//MKDIR  EXEC PGM=BPXBATCH" >> JCL
echo "//STDOUT DD SYSOUT=*" >> JCL
echo "//STDERR DD SYSOUT=*" >> JCL
echo "//STDPARM  DD *" >> JCL
echo "SH mkdir -p ${MOUNT}" >> JCL
echo "/*" >> JCL
echo "//MNT1ZFS1 EXEC PGM=IKJEFT01,REGION=4096K,DYNAMNBR=50" >> JCL
echo "//SYSTSPRT DD SYSOUT=*" >> JCL
echo "//SYSTSOUT DD SYSOUT=*" >> JCL
echo "//SYSTSIN DD * " >> JCL
echo "MOUNT FILESYSTEM('${ZFS}') +  " >> JCL
echo "TYPE(ZFS) MODE(RDWR) +     " >> JCL
echo "PARM('AGGRGROW') +   " >> JCL                  
echo "MOUNTPOINT('${MOUNT}')    " >> JCL                    
echo "/*" >> JCL

  sh scripts/submit_jcl.sh "`cat JCL`"
  if [ $? -gt 0 ];then exit -1;fi
  rm JCL
fi
