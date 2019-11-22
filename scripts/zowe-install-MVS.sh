#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2019, 2019
#######################################################################

sizeAUTH='space(15,15) tracks'
sizeSAMP='space(15,15) tracks'
members='ZOWESVR.jcl ZWESECUR.jcl'

# info: construct ${variable%%.*} keeps up to first . (exclusive)

# create MVS artifacts
script=zowe-install-MVS.sh
echo "<$script>" >> $LOG_FILE
echo "Creating MVS artifacts ... " >> $LOG_FILE

# Unpax the ZSS LOADLIB and SAMPLIB
echo "Unpax the LOADLIB and SAMPLIB:" >> ${LOG_FILE}
mkdir -p ${TEMP_DIR}/${script%%.*}/LOADLIB >> ${LOG_FILE} 2>&1
mkdir -p ${TEMP_DIR}/${script%%.*}/SAMPLIB >> ${LOG_FILE} 2>&1
dir=`pwd`
cd ${TEMP_DIR}/${script%%.*}
pax -rvf ${INSTALL_DIR}/files/zss.pax -ppx LOADLIB >> ${LOG_FILE} 2>&1
pax -rvf ${INSTALL_DIR}/files/zss.pax -ppx SAMPLIB >> ${LOG_FILE} 2>&1
cd $dir

# add non-ZSS members to staging area

for file in $members
do
  cp $INSTALL_DIR/files/templates/$file ${TEMP_DIR}/${script%%.*}/SAMPLIB/${file%%.*}
  rc=$?
  if test $rc -ne 0
  then
    echo "  $script $file not staged in ${TEMP_DIR}/${script%%.*}/SAMPLIB, RC=$rc" >> $LOG_FILE
  fi
done

# TODO remove once zowe/zss/samplib/zis/ is updated
# >>>>
# adjust ZSS samples
rm -f ${TEMP_DIR}/${script%%.*}/SAMPLIB/ZWESISMS
mv ${TEMP_DIR}/${script%%.*}/SAMPLIB/ZWESIS01 ${TEMP_DIR}/${script%%.*}/SAMPLIB/ZWESISTC
mv ${TEMP_DIR}/${script%%.*}/SAMPLIB/ZWESAUX ${TEMP_DIR}/${script%%.*}/SAMPLIB/ZWESASTC
if test ! -f ${TEMP_DIR}/${script%%.*}/SAMPLIB/ZWESIPRG
then
# Statements below must not exceed col 80
#----------------------------------------------------------------------------80|
cat > ${TEMP_DIR}/${script%%.*}/SAMPLIB/ZWESIPRG <<EndOfZWESIPRG
/* issue this console command to authorize the loadlib temporarily */
SETPROG APF,ADD,DSNAME=${ZOWE_DSN_PREFIX}.SZWEAUTH,VOLUME=${volume}
/* Add this statement to SYS1.PARMLIB(PROGxx) or equivalent
   to authorize the loadlib permanently */
APF ADD DSNAME(${ZOWE_DSN_PREFIX}.SZWEAUTH) VOLUME(${volume})
EndOfZWESIPRG
#----------------------------------------------------------------------------80|
fi
# <<<<

# TODO remove once zowe-install-packaging/files/templates is updated
# >>>>
# adjust non-ZSS samples
mv ${TEMP_DIR}/${script%%.*}/SAMPLIB/ZOWESVR ${TEMP_DIR}/${script%%.*}/SAMPLIB/ZWESTC
# <<<<


# 1. {datasetprefix}.SZWEAUTH

tsocmd "delete '${ZOWE_DSN_PREFIX}.SZWEAUTH' " >> ${LOG_FILE} 2>&1

# SZWEAUTH must be PDSE
# TODO replace by allocate-dataset.sh call to resuse VOLSER support
tsocmd "allocate new da('${ZOWE_DSN_PREFIX}.SZWEAUTH') " \
    "dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(6999)" \
    "unit(sysallda) $sizeAUTH" >> $LOG_FILE 2>&1
rc=$?
if test $rc -eq 0
then
    echo "  ${ZOWE_DSN_PREFIX}.SZWEAUTH successfully created" >> $LOG_FILE

    # copy LOADLIB to PDS
    echo "Copy LOADLIB to PDS:" >> ${LOG_FILE}
    for member in $(ls ${TEMP_DIR}/${script%%.*}/LOADLIB/)
    do
      cp -X -v ${TEMP_DIR}/${script%%.*}/LOADLIB/$member "//'${ZOWE_DSN_PREFIX}.SZWEAUTH'" >> ${LOG_FILE}

      rc=$?
      if test $rc -eq 0
      then
          echo "  $script $member copied to ${ZOWE_DSN_PREFIX}.SZWEAUTH" >> $LOG_FILE
      else
          echo "  $script $member not copied to ${ZOWE_DSN_PREFIX}.SZWEAUTH, RC=$rc" >> $LOG_FILE
      fi
    done
else
    echo "  $script failed to create ${ZOWE_DSN_PREFIX}.SZWEAUTH, RC=$rc" >> $LOG_FILE
fi


# 2. {datasetprefix}.SZWESAMP

tsocmd "delete '${ZOWE_DSN_PREFIX}.SZWESAMP' " >> ${LOG_FILE} 2>&1

# TODO replace by allocate-dataset.sh call to resuse VOLSER support
tsocmd "allocate new da('${ZOWE_DSN_PREFIX}.SZWESAMP') " \
    "dsntype(library) dsorg(po) recfm(f b) lrecl(80) " \
    "unit(sysallda) $sizeSAMP" >> $LOG_FILE 2>&1
rc=$?
if test $rc -eq 0
then
    echo "  ${ZOWE_DSN_PREFIX}.SZWESAMP successfully created" >> $LOG_FILE

    # copy SAMPLIB files to PDS
    echo "Copy SAMPLIB files to PDS:" >> ${LOG_FILE}

    for member in $(ls ${TEMP_DIR}/${script%%.*}/SAMPLIB/)
    do
        cp -v ${TEMP_DIR}/${script%%.*}/SAMPLIB/$member "//'${ZOWE_DSN_PREFIX}.SZWESAMP'" >> ${LOG_FILE}
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

rm -rf $TEMP_DIR/${script%%.*}

echo "</$script>" >> $LOG_FILE
