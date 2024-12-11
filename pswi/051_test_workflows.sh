#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"

echo ""
echo ""
echo "Script for testing workflows..."
echo "Host                   :" $ZOSMF_URL
echo "Port                   :" $ZOSMF_PORT
echo "SSH Port               :" $ZZOW_SSH_PORT
echo "z/OSMF system          :" $ZOSMF_SYSTEM
echo "Test HLQ               :" $TEST_HLQ
echo "Test mount point       :" $TEST_MOUNT
echo "Work zFS               :" $WORK_ZFS   # For z/OSMF v2.3
echo "Work mount point       :" $WORK_MOUNT # For z/OSMF v2.3

echo "Mounting ${TEST_HLQ}.ZFS"
sh scripts/tmp_mounts.sh "${TEST_HLQ}.ZFS" "${TEST_MOUNT}"
if [ $? -gt 0 ]; then exit -1; fi

echo "Registering/testing the configuration workflow ${TEST_HLQ}.WORKFLOW(ZWECONF)"
sh scripts/wf_run_test.sh "${TEST_HLQ}.WORKFLOW(ZWECONF)"
if [ $? -gt 0 ];then exit -1;fi

echo "Registering/testing the configuration workflow ${TEST_MOUNT}/files/workflows/ZWECONF.xml"
sh scripts/wf_run_test.sh "${TEST_MOUNT}/files/workflows/ZWECONF.xml"
if [ $? -gt 0 ];then exit -1;fi
