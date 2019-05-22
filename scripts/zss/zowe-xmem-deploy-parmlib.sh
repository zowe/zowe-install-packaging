#!/bin/sh

# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.

BASEDIR=$(dirname "$0")
ZSS=$1
parmlib=$2
parm=$3

rc=8

sh $BASEDIR/zowe-xmem-dataset-exists.sh ${parmlib}
if [[ $? -eq 0 ]]; then
  echo "Allocate ${parmlib}"
  tsocmd "allocate da('${parmlib}') dsntype(pds) dsorg(po) recfm(f,b) lrecl(80) blksize(23440) dir(64) space(10,2) tracks new " \
    1>/tmp/cmd.out 2>/tmp/cmd.err
  if [[ $? -eq 0 ]]
  then
    echo "Info:  dataset ${parmlib} has been successfully allocated"
    sleep 1 # Looks like the system needs some time to catalog the dataset
    rc=0
  else
    echo "Error:  dataset ${parmlib} has not been allocated"
    cat /tmp/cmd.out /tmp/cmd.err
    rc=8
  fi
else
  rc=0
fi

if [[ "$rc" = 0 ]] ; then
  echo "Copying parmlib member ${parm}"
  if ${BASEDIR}/ocopyshr.rexx ${ZSS}/SAMPLIB/${parm} "${parmlib}(${parm})" TEXT
  then
    echo "Info:  PARMLIB member ${parm} has been successfully copied to dataset ${parmlib}"
    rc=0
  else
    echo "Error:  PARMLIB member ${parm} has not been copied to dataset ${parmlib}"
    rc=8
  fi
fi

rm /tmp/cmd.out /tmp/cmd.err 1> /dev/null 2> /dev/null
exit $rc

