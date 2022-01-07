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
echo "//DELTZOWE EXEC PGM=IDCAMS" >> JCL1
echo "//SYSPRINT DD SYSOUT=*" >> JCL1
echo "//SYSIN    DD *" >> JCL1
echo " DELETE ${SMPE}.** MASK" >> JCL1
echo " SET MAXCC=0" >> JCL1
echo "/*" >> JCL1
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

if [ $PTFNR -eq 2 ]
then
cd unzipped
sshpass -p${ZOSMF_PASS} sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${TMP_MOUNT}
put ${RFDSNPFX}.${FMID}.${PTF1} ${PTF1}
put ${RFDSNPFX}.${FMID}.${PTF2} ${PTF2}
cp -F bin ${PTF1} "//'${SMPE}.${PTF1}'"
cp -F bin ${PTF2} "//'${SMPE}.${PTF2}'" 
EOF
else
sshpass -p${ZOSMF_PASS} sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${TMP_MOUNT}
put ${RFDSNPFX}.${FMID}.${PTF1} ${PTF1}
cp -F bin ${PTF1} "//'${SMPE}.${PTF1}'"
EOF
fi
fi
cd ..

rm -rf unzipped
