#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2019, 2020
#######################################################################

# Expected globals:
# $TEMP_DIR
# $INSTALL_DIR
# $LOG_FILE

sizeAUTH='space(30,15) tracks'
sizeSAMP='space(15,15) tracks'
members='ZWESVSTC.jcl ZWESECUR.jcl ZWENOSEC.jcl'

# NOTE FOR DEVELOPMENT
# Use functions _cp/_cpr/_pax to copy/recursive copy/unpax from 
# ${INSTALL_DIR}, as these will mark the source as processed. The build 
# pipeline will verify that all ${INSTALL_DIR} files are processed.
# Use function _cmd to add standard error handling to command execution.
# Use function _setInstallError in custom error handling.

# Note: construct ${variable%%.*} keeps up to first . (exclusive)

_scriptStart zowe-install-MVS.sh

TEMP_DIR_MVS=${TEMP_DIR}/${script%%.*}.$$

# Unpax the ZSS LOADLIB and SAMPLIB
echo "  Unpax the LOADLIB and SAMPLIB:" >> ${LOG_FILE}
_cmd mkdir -p ${TEMP_DIR_MVS}/LOADLIB
_cmd mkdir -p ${TEMP_DIR_MVS}/SAMPLIB
dir=`pwd`
cd ${TEMP_DIR_MVS}
_pax ${INSTALL_DIR}/files/zss.pax  LOADLIB
_pax ${INSTALL_DIR}/files/zss.pax  SAMPLIB
cd $dir

# add non-ZSS members to staging area

echo "  Add non-ZSS members to SAMPLIB:" >> ${LOG_FILE}
for file in $members
do
  _cp $INSTALL_DIR/files/jcl/$file  ${TEMP_DIR_MVS}/SAMPLIB/${file%%.*}
done

# TODO remove once https://github.com/zowe/zss/issues/94
# >>>>
# adjust ZSS samples
_cmd rm -f ${TEMP_DIR_MVS}/SAMPLIB/ZWESISMS
_cmd mv ${TEMP_DIR_MVS}/SAMPLIB/ZWESIS01 ${TEMP_DIR_MVS}/SAMPLIB/ZWESISTC
_cmd mv ${TEMP_DIR_MVS}/SAMPLIB/ZWESAUX ${TEMP_DIR_MVS}/SAMPLIB/ZWESASTC

if test ! -f ${TEMP_DIR_MVS}/SAMPLIB/ZWESIPRG
then
# Statements below must not exceed col 80
#----------------------------------------------------------------------------80|
cat > ${TEMP_DIR_MVS}/SAMPLIB/ZWESIPRG <<EndOfZWESIPRG
/* issue this console command to authorize the loadlib temporarily */
SETPROG APF,ADD,DSNAME=${ZOWE_DSN_PREFIX}.SZWEAUTH,VOLUME=${volume}
/* Add this statement to SYS1.PARMLIB(PROGxx) or equivalent
   to authorize the loadlib permanently */
APF ADD DSNAME(${ZOWE_DSN_PREFIX}.SZWEAUTH) VOLUME(${volume})
EndOfZWESIPRG
#----------------------------------------------------------------------------80|
  if test $? -ne 0
  then
    echo "Error: $script failed to create ${TEMP_DIR_MVS}/SAMPLIB/ZWESIPRG" | tee -a ${LOG_FILE}
    _setInstallError
  fi
fi    # ZWESIPRG did not exist
# <<<<

# 1. {datasetprefix}.SZWEAUTH

echo "  Populate ${ZOWE_DSN_PREFIX}.SZWEAUTH:" >> ${LOG_FILE}

# failure is OK since we don't test whether it exists
tsocmd "delete '${ZOWE_DSN_PREFIX}.SZWEAUTH' " 1>>/dev/null 2>&1

# SZWEAUTH must be PDSE
# TODO replace by allocate-dataset.sh call to reuse VOLSER support
tsocmd "allocate new da('${ZOWE_DSN_PREFIX}.SZWEAUTH') " \
    "dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760)" \
    "unit(sysallda) $sizeAUTH" 1>>${LOG_FILE} 2>&1
rc=$?
if test $rc -eq 0
then
  echo "  ${ZOWE_DSN_PREFIX}.SZWEAUTH successfully created" >> ${LOG_FILE}
  sleep 2     # allow time for dataset to be de-queued before attempting to copy members into it.

  # copy LOADLIB to PDS
  echo "  Copy LOADLIB to PDS:" >> ${LOG_FILE}
  for member in $(ls ${TEMP_DIR_MVS}/LOADLIB/)
  do
    # no _cp to avoid quoting issues and we do need to track this
    cp -X -v ${TEMP_DIR_MVS}/LOADLIB/$member "//'${ZOWE_DSN_PREFIX}.SZWEAUTH'" >> ${LOG_FILE} 2>&1
    rc=$?
    if test $rc -ne 0
    then
      echo "Error: $script $member not copied to ${ZOWE_DSN_PREFIX}.SZWEAUTH, RC=$rc" | tee -a ${LOG_FILE}
      _setInstallError
    fi
  done
else
  echo "Error: $script failed to create ${ZOWE_DSN_PREFIX}.SZWEAUTH, RC=$rc"  | tee -a ${LOG_FILE}
  _setInstallError
fi


# 2. {datasetprefix}.SZWESAMP

echo "  Populate ${ZOWE_DSN_PREFIX}.SZWESAMP:" >> ${LOG_FILE}

# failure is OK since we don't test whether it exists
tsocmd "delete '${ZOWE_DSN_PREFIX}.SZWESAMP' " 1>>/dev/null 2>&1

# TODO replace by allocate-dataset.sh call to resuse VOLSER support
tsocmd "allocate new da('${ZOWE_DSN_PREFIX}.SZWESAMP') " \
    "dsntype(library) dsorg(po) recfm(f b) lrecl(80) " \
    "unit(sysallda) $sizeSAMP" 1>>${LOG_FILE} 2>&1
rc=$?
if test $rc -eq 0
then
  echo "  ${ZOWE_DSN_PREFIX}.SZWESAMP successfully created" >> ${LOG_FILE}
  sleep 2     # allow time for dataset to be de-queued before attempting to copy members into it.

  # copy SAMPLIB files to PDS
  echo "Copy SAMPLIB files to PDS:" >> ${LOG_FILE}

  for member in $(ls ${TEMP_DIR_MVS}/SAMPLIB/)
  do
    # no _cp to avoid quoting issues and we do need to track this
    cp -v ${TEMP_DIR_MVS}/SAMPLIB/$member "//'${ZOWE_DSN_PREFIX}.SZWESAMP'" >> ${LOG_FILE} 2>&1
    rc=$?
    if test $rc -ne 0
    then
      echo "Error: $script $member not copied to ${ZOWE_DSN_PREFIX}.SZWESAMP, RC=$rc" | tee -a ${LOG_FILE}
      _setInstallError
    fi
  done
else
  echo "Error: $script failed to create ${ZOWE_DSN_PREFIX}.SZWESAMP, RC=$rc" | tee -a ${LOG_FILE}
  _setInstallError
fi

rm -rf ${TEMP_DIR_MVS} 1>>${LOG_FILE} 2>&1

_scriptStop
