#!/bin/sh

# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.

BASEDIR=$(dirname "$0")
# ZSS=$1
datasetPrefix=$1
loadlib=$2
loadmodule=$3

rc=8

sh $BASEDIR/zowe-xmem-dataset-exists.sh ${loadlib}
if [[ $? -ne 0 ]]; then
  sh $BASEDIR/zowe-xmem-check-if-pdse.sh ${loadlib}
  if [[ $? -ne 1 ]]; then
    echo "Error:  dataset ${loadlib} is not PDSE or the test failed. "
    echo  "If the PDSE test failed, please check the dataset in ISPF (=3.4, I) to see if its 'Data set name type' is LIBRARY."
    rc=8
  else
    rc=0
  fi
else
  echo "Allocate ${loadlib}"
  tsocmd "allocate da('${loadlib}') dsntype(library) dsorg(po) recfm(u) blksize(6144) space(10,2) tracks new " \
    1>/tmp/cmd.out 2>/tmp/cmd.err
  if [[ $? -eq 0 ]]
  then
    echo "Info:  dataset ${loadlib} has been successfully allocated"
    sleep 1 # Looks like the system needs some time to catalog the dataset
    rc=0
  else
    echo "Error:  dataset ${loadlib} has not been allocated"
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  fi
fi

if [[ "$rc" = 0 ]] ; then
  echo "Copying load module ${loadmodule}"
  if [ "$IS_SMPE_PACKAGE" = "yes" ]; then
    copyCommand="cp -X \"//'$datasetPrefix.SZWEAUTH(${loadmodule})'\" \"//'${loadlib}(${loadmodule})'\""
  else
    copyCommand="cp -X ${ZSS}/LOADLIB/${loadmodule} \"//'${loadlib}(${loadmodule})'\""
  fi

  # if cp -X ${ZSS}/LOADLIB/${loadmodule} "//'${loadlib}(${loadmodule})'"
  # if cp -X "//'$datasetPrefix.SZWEAUTH(${loadmodule})'" "//'${loadlib}(${loadmodule})'"
  if $copyCommand
  then
    echo "Info:  module ${loadmodule} has been successfully copied to dataset ${loadlib}"
    rc=0
  else
    echo "Error:  module ${loadmodule} has not been copied to dataset ${loadlib}"
    rc=8
  fi
fi

rm /tmp/cmd.out /tmp/cmd.err 1> /dev/null 2> /dev/null
exit $rc

