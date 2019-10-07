#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019, 2019
################################################################################

# create MVS artefacts 
script=zowe-create-MVS-artefacts.sh
echo "<$script>" >> $LOG_FILE 
echo "Creating MVS artefacts ... " >> $LOG_FILE 

# Unpax the LOADLIB and SAMPLIB
echo "Unpax the LOADLIB and SAMPLIB:" >> ${LOG_FILE}
mkdir -p ${TEMP_DIR}/files/zss/LOADLIB >> ${LOG_FILE} 2>&1
mkdir -p ${TEMP_DIR}/files/zss/SAMPLIB >> ${LOG_FILE} 2>&1
dir=`pwd`
cd ${TEMP_DIR}/files/zss
pax -rvf ${INSTALL_DIR}/files/zss.pax -ppx LOADLIB >> ${LOG_FILE} 2>&1
pax -rvf ${INSTALL_DIR}/files/zss.pax -ppx SAMPLIB >> ${LOG_FILE} 2>&1
cd $dir 

# 1. {datasetprefix}.SZWEAUTH
#      ZWESIS01 

tsocmd "delete '${ZOWE_DSN_PREFIX}.SZWEAUTH' " >> ${LOG_FILE} 2>&1

tsocmd "allocate new da('${ZOWE_DSN_PREFIX}.SZWEAUTH') " \
    "dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(6999)" \
    "space(5,2) tracks unit(sysallda)" >> $LOG_FILE 2>&1
rc=$?
if test $rc -eq 0
then
    echo "  ${ZOWE_DSN_PREFIX}.SZWEAUTH successfully created" >> $LOG_FILE

    # copy LOADLIB to PDS
    echo "Copy LOADLIB to PDS:" >> ${LOG_FILE}
    cp -X -v ${TEMP_DIR}/files/zss/LOADLIB/ZWESIS01 "//'${ZOWE_DSN_PREFIX}.SZWEAUTH(ZWESIS01)'" >> ${LOG_FILE}
    
    rc=$?
    if test $rc -eq 0
    then
        echo "  $script ZWESIS01 copied to ${ZOWE_DSN_PREFIX}.SZWEAUTH" >> $LOG_FILE
    else
        echo "  $script ZWESIS01 not copied to ${ZOWE_DSN_PREFIX}.SZWEAUTH, RC=$rc" >> $LOG_FILE
    fi 

else
    echo "  $script failed to create ${ZOWE_DSN_PREFIX}.SZWEAUTH, RC=$rc" >> $LOG_FILE
fi




# 2. {datasetprefix}.SZWESAMP

tsocmd "delete '${ZOWE_DSN_PREFIX}.SZWESAMP' " >> ${LOG_FILE} 2>&1
tsocmd "allocate new da('${ZOWE_DSN_PREFIX}.SZWESAMP') " \
    "dsntype(library) dsorg(po) recfm(f b) lrecl(80) " \
    "space(5,2) tracks unit(sysallda)" >> $LOG_FILE 2>&1
rc=$?
if test $rc -eq 0
then
    echo "  ${ZOWE_DSN_PREFIX}.SZWESAMP successfully created" >> $LOG_FILE

    # copy SAMPLIB files to PDS
    echo "Copy SAMPLIB files to PDS:" >> ${LOG_FILE}

    # ... obtain members as yet not in zss.pax file ...

    # cp $INSTALL_DIR/files/templates/ZWESECUR.jcl ${TEMP_DIR}/files/zss/SAMPLIB/ZWESECUR # stagings/cupids

# Statements below must not exceed col 80
#----------------------------------------------------------------------------80|
cat > ${TEMP_DIR}/files/zss/SAMPLIB/ZWESIPRG <<EndOfZWESIPRG
/* issue this console command to authorize the loadlib temporarily */
SETPROG APF,ADD,DSNAME=${ZOWE_DSN_PREFIX}.SZWEAUTH,VOLUME=${volume}
/* Add this statement to SYS1.PARMLIB(PROGxx) or equivalent 
   to authorize the loadlib permanently */
APF ADD DSNAME(${ZOWE_DSN_PREFIX}.SZWEAUTH) VOLUME(${volume}) 
EndOfZWESIPRG
#----------------------------------------------------------------------------80|

    mv ${TEMP_DIR}/files/zss/SAMPLIB/ZWESIS01 ${TEMP_DIR}/files/zss/SAMPLIB/ZWESISTC

    cp $INSTALL_DIR/files/templates/ZOWESVR.template.jcl ${TEMP_DIR}/files/zss/SAMPLIB/ZOWESVR # unconfigured
    
    for member in ZWESIP00 ZWESISCH ZWESISMS ZOWESVR  ZWESISTC ZWESIPRG # ZWESECUR (will come from stagings/cupids)
    do
        cp -v ${TEMP_DIR}/files/zss/SAMPLIB/$member "//'${ZOWE_DSN_PREFIX}.SZWESAMP($member)'" >> ${LOG_FILE}
        rc=$?
        if test $rc -eq 0
        then
            echo "  $script $member copied to ${ZOWE_DSN_PREFIX}.SZWESAMP" >> $LOG_FILE
        else
            echo "  $script $member not copied to ${ZOWE_DSN_PREFIX}.SZWESAMP, RC=$rc" >> $LOG_FILE
        fi 
    done
else
    echo "  $script failed to create ${ZOWE_DSN_PREFIX}.SZWESAMP, RC=$rc" >> $LOG_FILE
fi

rm -rf $TEMP_DIR

echo "</$script>" >> $LOG_FILE 
