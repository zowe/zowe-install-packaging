export ZOSMF_URL="https://zzow03.zowe.marist.cloud"
export ZOSMF_PORT=10443
export ZOSMF_SYSTEM="S0W1"
export DIR="/u/zowead2"
export CSIHLQ="ZWE.PSWI.AZWE001"
export ZONE="TZONE"
export TMP_ZFS="ZOWEAD2.TMP.ZFS"
export ZOWE_ZFS="${CSIHLQ}.ZFS"
export ZOWE_MOUNT="/u/zwe/zowe-smpe/"
export VOLUME="ZOS003"
export TEST_HLQ="ZOWEAD2.PSWIT"
export SYSAFF=2964 
export ACCOUNT=1

# Variables for workflows
# SMPE
export SMPMCS="ZOWEAD2"
export FMID="AZWE001"
export RFDSNPFX="ZOWE"
export CSIVOL="ZOS003"
export TZONE=$ZONE
# CSIHLQ for workflow is same as for PSWI
export DZONE="DZONE"
export THLQ="${CSIHLQ}.T"
export DHLQ="${CSIHLQ}.D"
export TVOL=$CSIVOL
export DVOL=$CSIVOL
export MOUNTPATH=$ZOWE_MOUNT
#PTF
export CSI=$CSIHLQ
export PTFDATASET="ZOWEAD2.ZOWE.AZWE001"
export TARGET=$TZONE
export DISTRIBUTION=$DZONE
export PTF1="UO01994"
export PTF2="UO01995"

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
export TEST_MOUNT="${TMP_MOUNT}/test_mount"
export EXPORT="${TMP_MOUNT}/export/"
export WORK_MOUNT="${DIR}/work"
export WORK_ZFS="ZOWEAD2.WORK.ZFS"
export GLOBAL_ZONE=${CSIHLQ}.CSI
export EXPORT_DSN=${CSIHLQ}.EXPORT
export WORKFLOW_DSN=${CSIHLQ}.WORKFLOW
export ZOSMF_V="2.3"
export SMPE_WF_NAME="ZOWE_SMPE_WF"
export PTF_WF_NAME="ZOWE_PTF_WF"
export OUTPUT_ZFS="ZOWEAD2.OUTPUT.PSWI.ZFS"
export OUTPUT_MOUNT="/u/zowead2/PSWI"

# Create SMP/E
sh 01_smpe.sh
smpe=$?

if [ $smpe -eq 0 ];then
# Apply PTFs
sh 02_ptf.sh
ptf=$?

if [ $ptf -eq 0 ];then
# Create PSWI
sh 03_create.sh
create=$?

# Cleanup after the creation of PSWI
sh 04_create_cleanup.sh

if [ $create -eq 0 ];then 
# Test PSWI
sh 05_test.sh
test=$?

# Cleanup after the test
sh 06_test_cleanup.sh
fi 
fi 
fi

# Cleanup of SMP/E
sh 07_smpe_cleanup.sh

echo ""
echo ""

if [ $smpe -ne 0 ] || [ $ptf -ne 0 ] || [ $create -ne 0 ] || [ $test -ne 0 ]
then
  echo "Build unsuccessful!"
  if [ $smpe -ne 0 ]; then
    echo "SMP/E wasn't successful."
  elif [ $ptf -ne 0 ]; then
    echo "Applying PTFs wasn't successful."
  elif [ $create -ne 0 ]; then
    echo "Creation of SMP/E wasn't successful."
  elif [ $test -ne 0 ]; then
    echo "Testing of PSWI wasn't successful."
  fi
  exit -1
else
  echo "Build successful!"
  exit 0
fi
