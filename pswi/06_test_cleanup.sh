#!/bin/sh
#version=1.0

export BASE_URL="${ZOSMF_URL}:${ZOSMF_PORT}"
LOG_FILE=$LOG_DIR/log_test_cleanup.txt

echo ""
echo ""
echo "Script for clean-up after a testing of Portable Software Instance..."
echo "Host                        :" $ZOSMF_URL
echo "Port                        :" $ZOSMF_PORT
echo "z/OSMF system               :" $ZOSMF_SYSTEM
echo "HLQ for datasets            :" $TEST_HLQ
echo "Portable Software Instance  :" $PSWI
echo "Software instance name      :" $DEPLOY_NAME
echo "Temporary zFS               :" $TMP_ZFS
echo "Work zFS                    :" $WORK_ZFS # For z/OSMF v2.3
echo "Directory for logs          :" $LOG_DIR
echo "ACCOUNT                     :" $ACCOUNT
echo "SYSAFF                      :" $SYSAFF
echo "z/OSMF version              :" $ZOSMF_V

# URLs
DELETE_PSWI_URL="${BASE_URL}/zosmf/swmgmt/pswi/${ZOSMF_SYSTEM}/${PSWI}"
WORKFLOW_LIST_URL="${BASE_URL}/zosmf/workflow/rest/1.0/workflows?owner=${ZOSMF_USER}&workflowName=${WORKFLOW_NAME}.*"
DELETE_DEPL_SWI_URL="${BASE_URL}/zosmf/swmgmt/swi/${ZOSMF_SYSTEM}/${DEPLOY_NAME}"

# Create a log file
touch $LOG_FILE

# Delete the Software instance
echo "Invoking REST API to delete the Software Instance created by deployment."

RESP=$(curl -s $DELETE_DEPL_SWI_URL -k -X "DELETE" -H "Content-Type: application/json" -H "X-CSRF-ZOSMF-HEADER: A" --user $ZOSMF_USER:$ZOSMF_PASS)
sh scripts/check_response.sh "${RESP}" $?

# Unmount and delete
echo "Unmounting and deleting zFS ${TMP_ZFS}."

echo ${JOBST1} >JCL
echo ${JOBST2} >>JCL
echo "//UNMNTZFS EXEC PGM=IKJEFT01,REGION=4096K,DYNAMNBR=50" >>JCL
echo "//SYSTSPRT DD SYSOUT=*" >>JCL
echo "//SYSTSOUT DD SYSOUT=*" >>JCL
echo "//SYSTSIN DD * " >>JCL
echo "UNMOUNT FILESYSTEM('${TMP_ZFS}') +  " >>JCL
echo "IMMEDIATE" >>JCL
echo "/*" >>JCL
echo "//DELTZFST EXEC PGM=IDCAMS" >>JCL
echo "//SYSPRINT DD SYSOUT=*" >>JCL
echo "//SYSIN    DD *" >>JCL
echo " DELETE ${TMP_ZFS}" >>JCL
echo "/*" >>JCL

sh scripts/submit_jcl.sh "$(cat JCL)"
# Not checking results so the script doesn't fail
rm JCL



# Unmount and delete
echo "Unmounting and deleting zFS ${TEST_HLQ}.ZFS."

echo ${JOBST1} >JCL
echo ${JOBST2} >>JCL
echo "//UNMNTZFS EXEC PGM=IKJEFT01,REGION=4096K,DYNAMNBR=50" >>JCL
echo "//SYSTSPRT DD SYSOUT=*" >>JCL
echo "//SYSTSOUT DD SYSOUT=*" >>JCL
echo "//SYSTSIN DD * " >>JCL
echo "UNMOUNT FILESYSTEM('${TEST_HLQ}.ZFS.#') +  " >>JCL
echo "IMMEDIATE" >>JCL
echo "/*" >>JCL
echo "//UNMNTZF2 EXEC PGM=IKJEFT01,REGION=4096K,DYNAMNBR=50" >>JCL
echo "//SYSTSPRT DD SYSOUT=*" >>JCL
echo "//SYSTSOUT DD SYSOUT=*" >>JCL
echo "//SYSTSIN DD * " >>JCL
echo "UNMOUNT FILESYSTEM('${TEST_HLQ}.ZFS') +  " >>JCL
echo "IMMEDIATE" >>JCL
echo "/*" >>JCL
echo "//DELTZFST EXEC PGM=IDCAMS" >>JCL
echo "//SYSPRINT DD SYSOUT=*" >>JCL
echo "//SYSIN    DD *" >>JCL
echo " DELETE ${TEST_HLQ}.ZFS" >>JCL
echo " DELETE ${TEST_HLQ}.ZFS.#" >>JCL
echo "/*" >>JCL

sh scripts/submit_jcl.sh "$(cat JCL)"
# Not checking results so the script doesn't fail
rm JCL

# Delete deployed datasets
echo "Deleting deployed datasets."

echo ${JOBST1} >JCL
echo ${JOBST2} >>JCL
echo "//DELTZOWE EXEC PGM=IDCAMS" >>JCL
echo "//SYSPRINT DD SYSOUT=*" >>JCL
echo "//SYSIN    DD *" >>JCL
echo " DELETE ${TEST_HLQ}.** MASK" >>JCL
echo " SET MAXCC=0" >>JCL
echo "/*" >>JCL

sh scripts/submit_jcl.sh "$(cat JCL)"
rm JCL


# Unmount and delete
echo "Unmounting and deleting zFS ${WORK_ZFS}."

echo ${JOBST1} >JCL
echo ${JOBST2} >>JCL
echo "//UNMNTZFS EXEC PGM=IKJEFT01,REGION=4096K,DYNAMNBR=50" >>JCL
echo "//SYSTSPRT DD SYSOUT=*" >>JCL
echo "//SYSTSOUT DD SYSOUT=*" >>JCL
echo "//SYSTSIN DD * " >>JCL
echo "UNMOUNT FILESYSTEM('${WORK_ZFS}') +  " >>JCL
echo "IMMEDIATE" >>JCL
echo "/*" >>JCL
echo "//DELTZFST EXEC PGM=IDCAMS" >>JCL
echo "//SYSPRINT DD SYSOUT=*" >>JCL
echo "//SYSIN    DD *" >>JCL
echo " DELETE ${WORK_ZFS}" >>JCL
echo "/*" >>JCL

sh scripts/submit_jcl.sh "$(cat JCL)"
# Not checking results so the script doesn't fail
rm JCL
