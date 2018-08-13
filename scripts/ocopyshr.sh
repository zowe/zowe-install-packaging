#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

#
# Script to copy a uss JCL file to a shared PDS using a CLIST.
# The name of the uss file has already been edited into the CLIST.
#
if [[ $# != 2 ]] then
	echo Usage: ocopyshr.sh topds tomember
	echo topds    = DSN of PROCLIB where uss JCL file will be placed
	echo tomember = member name in PROCLIB for uss JCL file
	exit 1
fi
topds=$1
tomember=$2
tsocmd exec zowetemp\(copyproc\) \'$topds $tomember\'   1>/dev/null 2>/dev/null
rc=$?

exit $rc

