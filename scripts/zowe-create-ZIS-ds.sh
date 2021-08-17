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

sizePLUG='space(30,15) tracks'

script=zowe-create-ZIS-ds.sh
echo "<$script>" >> $LOG_FILE
echo "Creating dataset for ZIS plugins ... " >> $LOG_FILE

# 1. {datasetprefix}.SZWEPLUG

# TODO replace by allocate-dataset.sh call to resuse VOLSER support
tsocmd "allocate new da('${ZOWE_DSN_PREFIX}.SZWEPLUG') " \
    "dsntype(library) dsorg(po) recfm(u) lrecl(0) bLKSIZE(32760)" \
    "unit(sysallda) $sizePLUG" < /dev/null >> $LOG_FILE 2>&1
rc=$?
if test $rc -eq 0
then
    echo "  ${ZOWE_DSN_PREFIX}.SZWEPLUG successfully created" >> $LOG_FILE
else
    echo "  $script failed to create ${ZOWE_DSN_PREFIX}.SZWEPLUG, RC=$rc" >> $LOG_FILE
fi

echo "</$script>" >> $LOG_FILE