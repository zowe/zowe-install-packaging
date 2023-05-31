export ZOSMF_URL="https://zzow03.zowe.marist.cloud"
export ZOSMF_PORT=10443
export ZOSMF_SYSTEM="S0W1"
export DIR="/u/zowead2"
export SMPEHLQ="ZOWEAD2"
export TMP_ZFS="ZOWEAD2.TMP.ZFS"
export ZOWE_MOUNT="/u/zwe/zowe-smpe/"
export VOLUME="ZOS003"
export TEST_HLQ="ZOWEAD2.PSWIT"
export SYSAFF="(2964,S0W1)" 
export ACCOUNT=1

# Variables for workflows
# SMPE
export TZONE="TZONE"
export DZONE="DZONE"

export JOBNAME="ZWEPSWI1"
if [ -n "$ACCOUNT" ]
then
export JOBST1="//"${JOBNAME}" JOB ("${ACCOUNT}"),'PSWI',MSGCLASS=A,REGION=0M"
else
export JOBST1="//"${JOBNAME}" JOB 'PSWI',MSGCLASS=A,REGION=0M"
fi
export JOBST2="/*JOBPARM SYSAFF=${SYSAFF}"
export DEPLOY_NAME="DEPLOY"
export PSWI="zowe-PSWI"
export SWI_NAME=$PSWI
export TMP_MOUNT="${DIR}/zowe-tmp"
export TEST_MOUNT="${DIR}/test_mount"
export EXPORT="${TMP_MOUNT}/export/"
export WORK_MOUNT="${DIR}/work"
export WORK_ZFS="ZOWEAD2.WORK.ZFS"
export ZOSMF_V="2.3"
export SMPE_WF_NAME="ZOWE_SMPE_WF"
export PTF_WF_NAME="ZOWE_PTF_WF"
export HOST=${ZOSMF_URL#https:\/\/}
echo "--------------------------------- Getting build specific variables ---------------------------------------"

if [ -f ../.pax/zowe-smpe.zip ]
then
  echo "ok"
  mkdir -p "unzipped"
  unzip ../.pax/zowe-smpe.zip -d unzipped
else
  echo "zowe-smpe file not found"
  exit -1
fi

if [ -f unzipped/*.pax.Z ]
then
  echo "it's new fmid"
  export FMID=`ls unzipped | tail -n 1 | cut -f1 -d'.'`
  export RFDSNPFX=`cat unzipped/*htm | grep -o "hlq.*.${FMID}.F1" | cut -f2 -d'.'`
else
  echo "it's ptf/apar"
  mv unzipped/*htm ptfs.html
  export PTFNR=`ls unzipped | wc -l`
  
  if [ $PTFNR -le 2 ]
  then
    echo "standard situation"
    export RFDSNPFX=`ls unzipped | tail -n 1 | cut -f1 -d'.'`
    export FMID=`ls unzipped | tail -n 1 | cut -f2 -d'.'`
    
    FILES=`ls unzipped`
    N=0
    for FILE in $FILES
    do
      N=$((N+1))
      export PTF${N}=`echo $FILE | tail -n 1 | cut -f3 -d'.'`
    done
  else
    echo "Different number of files"
    #TODO:make it more universal (we have the workflow now just for two files anyway so change it with that)
  fi

  if [ -f ../.pax/${FMID}.zip ]
  then
    unzip ../.pax/${FMID}.zip -d unzipped
  else
    echo "File with FMID not found"
    exit -1
  fi
fi
export SMPE="${SMPEHLQ}.${RFDSNPFX}.${FMID}"
echo "----------------------------------------------------------------------------------------------------------"

# More variables
export CSIHLQ="ZWE.PSWI.${FMID}"
export THLQ="${CSIHLQ}.T"
export DHLQ="${CSIHLQ}.D"
export GLOBAL_ZONE=${CSIHLQ}.CSI
export EXPORT_DSN=${CSIHLQ}.EXPORT
export WORKFLOW_DSN=${CSIHLQ}.WORKFLOW
export ZOWE_ZFS="${CSIHLQ}.ZFS"
export VERSION=`cat ../manifest.json.template | grep -o '"version": ".*"' | head -1 | cut -f4 -d\"`

# Upload and prepare all files
sh 00_presmpe.sh
presmpe=$?

if [ $presmpe -eq 0 ];then
# Create SMP/E
sh 01_smpe.sh
smpe=$?

if [ $smpe -eq 0 ];then
if [ -n "$PTFNR" ];then
# Apply PTFs
sh 02_ptf.sh
ptf=$?
else
# There are no PTFs
ptf=0
fi 

if [ $ptf -eq 0 ];then
# Create PSWI
sh 03_create.sh
create=$?

# Cleanup after the creation of PSWI
sh 04_create_cleanup.sh
# Cleanup of SMP/E
sh 07_smpe_cleanup.sh
# Clean RELFILEs and PTFs
sh 08_presmpe_cleanup.sh

if [ $create -eq 0 ];then 
# Test PSWI
sh 05_test.sh
test=$?

# Cleanup after the test
sh 06_test_cleanup.sh
fi 
else
  # Cleanup of SMP/E if PTF weren't successful - because the earlier cleanup runs only it it was success
  sh 07_smpe_cleanup.sh 
  # Clean RELFILEs and PTFs
sh 08_presmpe_cleanup.sh
fi 
else
  # Cleanup of SMP/E if SMPE weren't successful - because the earlier cleanup runs only it it was success
  sh 07_smpe_cleanup.sh 
  # Clean RELFILEs and PTFs
sh 08_presmpe_cleanup.sh
fi
fi 

echo ""
echo ""

if [ $smpe -ne 0 ] || [ $ptf -ne 0 ] || [ $create -ne 0 ] || [ $test -ne 0 ] || [ $presmpe -ne 0 ]
then
  echo "Build unsuccessful!"
  if [ $presmpe -ne 0 ]; then
    echo "Pre-SMP/E wasn't successful."
  elif [ $smpe -ne 0 ]; then
    echo "SMP/E wasn't successful."
  elif [ $ptf -ne 0 ]; then
    echo "Applying PTFs wasn't successful."
  elif [ $create -ne 0 ]; then
    echo "Creation of PSWI wasn't successful."
  elif [ $test -ne 0 ]; then
    echo "Testing of PSWI wasn't successful."
  fi
  exit -1
else
  echo "Build successful!"
  exit 0
fi
