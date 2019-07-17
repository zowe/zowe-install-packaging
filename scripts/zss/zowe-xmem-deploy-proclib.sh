#!/bin/sh

# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.

proclib=$1
jclfile=$2
member=$3

sh ${SCRIPT_DIR}/zowe-xmem-dataset-exists.sh ${proclib}
if [[ $? -eq 0 ]]; then
  echo "Error:  PROCLIB ${XMEM_PROCLIB} doesn't exist"
  return 8
fi

echo "Copy PROCLIB member ${member} to ${proclib}"
if ${SCRIPT_DIR}/ocopyshr.rexx ${ZSS}/SAMPLIB/${jclfile} "${proclib}(${member})" TEXT
then
  echo "Info:  PROCLIB member ${member} has been successfully copied to dataset ${proclib}"
  return 0
else
  echo "Error:  PROCLIB member ${member} has not been copied to dataset ${proclib}"
  return 8
fi

