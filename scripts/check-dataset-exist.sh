#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# 5698-ZWE Copyright Contributors to the Zowe Project. 2019, 2019
#######################################################################

# Test if dsn exists.
#
# Arguments:
# dsn  data set name
#
# Expected globals:
# $debug
#
# Return code:
# 0: data set exists
# 1: data set does not exist
# 8: error

me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo "> $me $@"

# Ensure the rc variable is null
unset rc

# Get startup arguments
dsn="$1"

# Get data set information
cmd="listds '$dsn'"
cmdOut="$(tsocmd "$cmd" 2>&1)"
if test $? -ne 0
then
  noCatalog="$(echo $cmdOut | grep 'NOT IN CATALOG$')"
  if test "$noCatalog"
  then
    test "$debug" && echo "data set $dsn does not exist"
    rc=1
  else
    echo "** ERROR $me LISTDS failed"
    echo "$cmd"
    echo "$cmdOut"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
else
  test "$debug" && echo "data set $dsn exists"
fi    #
test "$debug" && echo "$cmdOut"
# sample output:
#listds 'IBMUSER.ZWE.SZWESAMP'
#IBMUSER.ZWE.SZWESAMP
#--RECFM-LRECL-BLKSIZE-DSORG
#  FB    80    32720   PO
#--VOLUMES--
#  U00230
# sample output:
#listds 'IBMUSER.ZWE.SZWESAMP'
#IBMUSER.ZWE.SZWESAMP
#IKJ58503I DATA SET 'IBMUSER.ZWE.SZWESAMP' NOT IN CATALOG

# If not set, set rc to 0
test -z "$rc" && rc=0

test "$debug" && echo "< $me $rc"
exit $rc
