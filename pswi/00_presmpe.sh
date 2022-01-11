#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"

echo ""
echo ""
echo "Script for preparing datasets for SMP/E (PTFs)..."
echo "Host               :" $ZOSMF_URL
echo "Port               :" $ZOSMF_PORT
echo "z/OSMF system      :" $ZOSMF_SYSTEM
echo "FMID               :" $FMID
echo "RFDSNPFX           :" $RFDSNPFX
echo "SMPE data sets     :" $SMPE
echo "Temporary zFS      :" $TMP_ZFS
echo "Temporary directory:" $TMP_MOUNT
if [ -n "$PTFNR" ]
then
echo "Number of PTFs     :" $PTFNR 
echo "PTF1               :" $PTF1
echo "PTF2               :" $PTF2
fi 

# URLs
ACTION_TMP_ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/${TMP_ZFS}"
ZFS_URL="${BASE_URL}/zosmf/restfiles/mfs/zfs/${TMP_ZFS}"

# JSONs  
UNMOUNT_ZFS_JSON='{"action":"unmount"}'

echo "Checking/mounting ${TMP_ZFS}"
sh scripts/tmp_mounts.sh "${TMP_ZFS}" "${TMP_MOUNT}"
if [ $? -gt 0 ];then exit -1;fi 

HOST=${ZOSMF_URL#https:\/\/}

cd unzipped
sshpass -p${ZOSMF_PASS} sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${TMP_MOUNT}
put ${FMID}.pax.Z
EOF
cd ..

echo "Preparing SMPMCS and RELFILES"
line=`cat unzipped/${FMID}.readme.txt | grep -n //UNPAX | cut -f1 -d:`
echo $JOBST1 > JCL1
echo $JOBST2 >> JCL1
cat unzipped/${FMID}.readme.txt | tail -n +$line >> JCL1
sed "s|@zfs_path@|${TMP_MOUNT}|g" JCL1 > JCL2
sed "s|@PREFIX@|${SMPEHLQ}|g" JCL2 > JCL1
sed "s|newname=\"...\"/>|newname=\"...\"|g" JCL1 > JCL2
sed "s|/>|\n         volume=\"${VOLUME}\"/>|g" JCL2 > JCL1
sed "s|<GIMUNZIP>|<GIMUNZIP>\n<TEMPDS volume=\"${VOLUME}\"> </TEMPDS>|g" JCL1 > JCL
rm JCL1
rm JCL2

sh scripts/submit_jcl.sh "`cat JCL`"
if [ $? -gt 0 ];then exit -1;fi
rm JCL



if [ -n "$PTFNR" ]
then
  # There are PTFs
echo "Allocating PTF datasets"
line=`cat ptfs.html | grep -n //ALLOC | cut -f1 -d:`
echo $JOBST1 > JCL1
echo $JOBST2 >> JCL1
echo "//         SET HLQ=${SMPEHLQ}" >> JCL1
cat ptfs.html | tail -n +$line >> JCL1
endline=`cat JCL1 | grep --max-count=1 -n \</PRE\> | cut -f1 -d:`
cat JCL1 | head -n $((endline-1)) > JCL2
sed "s|//\*            VOL=SER=<STRONG>#volser</STRONG>,|//            VOL=SER=${VOLUME},|g" JCL2 > JCL
rm JCL1
rm JCL2

sh scripts/submit_jcl.sh "`cat JCL`"
if [ $? -gt 0 ];then exit -1;fi
rm JCL
  
  echo "Uploading PTFs"

cd unzipped
if [ $PTFNR -eq 2 ]
then
sshpass -p${ZOSMF_PASS} sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${TMP_MOUNT}
put ${RFDSNPFX}.${FMID}.${PTF1} ${PTF1}
put ${RFDSNPFX}.${FMID}.${PTF2} ${PTF2}
EOF
else
sshpass -p${ZOSMF_PASS} sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${TMP_MOUNT}
put ${RFDSNPFX}.${FMID}.${PTF1} ${PTF1}
EOF
fi
cd ..

echo "Copying PTFs to ${SMPE} data set."

echo ${JOBST1} > JCL
echo ${JOBST2} >> JCL
echo "//COPYWRFS EXEC PGM=BPXBATCH" >> JCL
echo "//STDOUT DD SYSOUT=*" >> JCL
echo "//STDERR DD SYSOUT=*" >> JCL
echo "//STDPARM  DD *" >> JCL
echo "SH set -x;" >> JCL 
echo "source=\"${TMP_MOUNT}/${PTF1}\";" >> JCL
echo "target=\"//'${SMPE}.${PTF1}'\";" >> JCL
echo "cp -F bin \$source \$target;" >> JCL
if [ $PTFNR -eq 2 ]
then
echo "source=\"${TMP_MOUNT}/${PTF2}\";" >> JCL
echo "target=\"//'${SMPE}.${PTF2}'\";" >> JCL
echo "cp -F bin \$source \$target;" >> JCL
fi
echo "/*" >> JCL

sh scripts/submit_jcl.sh "`cat JCL`"
if [ $? -gt 0 ];then exit -1;fi
rm JCL
fi

rm -rf unzipped

# Need to unmount temporary ZFS so there won't be anything taking up space for next steps
echo "Invoking REST API to unmount TEMP zFS ${TMP_ZFS} from its mountpoint."

RESP=`curl -s $ACTION_TMP_ZFS_URL -k -X "PUT" -d "$UNMOUNT_ZFS_JSON" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?

# Delete
echo "Invoking REST API to delete ${TMP_ZFS} zFS."

RESP=`curl -s $ZFS_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS`
sh scripts/check_response.sh "${RESP}" $?
