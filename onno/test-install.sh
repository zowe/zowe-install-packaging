#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2020, 2020
#######################################################################
#
# install Zowe and grab result details
#
if test "$1" = "old" ; then
  shift
  key=old
  source=/VM30094/tmp/zowe-1.14.0
else
  key=new
  source=/VM30096/tmp/zowe-1.14.0
  # source delta with old:
  # - files/data-sets-api-server-*.pax -> files/files-api-server-*.pax
  # - install/zowe-install.sh
  # - scripts/zowe-install-*.sh
fi
target=/VM30094/tmp/zowe-${key}
dataset=BLD.ZOWE.${key}
#
echo "test cleanup ..."
rm -r $source/logs 1>/dev/null 2>&1
rm -r $target 1>/dev/null 2>&1
tsocmd "DELETE '$dataset.SZWEAUTH'" 1>/dev/null 2>&1
tsocmd "DELETE '$dataset.SZWESAMP'" 1>/dev/null 2>&1
#
echo "test install ..."
mkdir $source/logs
cd $source/install
./zowe-install.sh -i $target \
                  -h $dataset \
                  -l $source/logs \
                  $@ \
  1>$source/logs/zowe-output-${key}.log 2>&1
rc=$?  
echo "test install RC=$rc" 1>$source/logs/zowe-rc-${key}.log 2>&1
cat $source/logs/zowe-output-${key}.log
cat $source/logs/zowe-rc-${key}.log
#
echo "test snapshot ..."
cd $target
# show hidden, long, extended, recursive, tag
# sed changes date & time to <date> to simplify compare
mask="... .. ..:.."                                                 
ls -AlERT 2>&1 \                                                    
  | sed "s#\(.*${LOGNAME}.*[[:digit:]]* \)$mask\(.*\)#\1<date>\2#" \
  1>$source/logs/zowe-ls-${key}.log 2>&1
# rename install log to zowe-install-$key.log
log=$(ls $source/logs/zowe-install-*.log)
mv ${log} ${log%l-*}l-${key}.log
# show name of available logs
echo
ls $source/logs/zowe-install-${key}.log
ls $source/logs/zowe-ls-${key}.log
ls $source/logs/zowe-output-${key}.log
ls $source/logs/zowe-rc-${key}.log
