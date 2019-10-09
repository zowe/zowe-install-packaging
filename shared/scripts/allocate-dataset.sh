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

# Allocate data set if needed, test existing data set for correct DCB.
#
# Arguments:
# -e        (optional) existing partitioned data set must be PDS/E
# -h        (optional) hide the allocate command being issued
# -p        (optional) existing partitioned data set must be PDS
# -P dirBlk (optional) allocate data set as PDS with x directory blocks
# -V volume (optional) allocate data set on specified volume(s)
# dsn       data set name
# recFm     record format; {FB | FBA | U | VB | VBA}
# lRecL     logical record length, use ** for RECFM(U)
# dsOrg     data set organisation; {PO | PS}
# space     space in tracks; primary[,secondary]
#
# Expected globals:
# $debug $LOG_FILE
#
# Return code:
# 0: data set created or reused
# 1: data set exists with different DCB
# 2: existing partitioned data set does not match PDS(E) requirement
# 8: error

dcbScript=check-dataset-dcb.sh # script to test dcb of data set
existScript=check-dataset-exist.sh  # script to test if data set exists
here=$(cd $(dirname $0);pwd)   # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo "> $me $@"

# Ensure the rc variable is null
unset rc

# Clear input variables
unset pdse hide pds dir volume

# Get startup arguments
args="$@"
while getopts ehpP:V: opt
do case "$opt" in
  e)   pdse="-e";;
  h)   hide="-h";;
  p)   pds="-p";;
  P)   dir="$OPTARG";;
  V)   volume="$OPTARG";;
  [?]) echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

dsn="$1"
recFm="$2"
lRecL="$3"
dsOrg="$4"
space="$5"

# Input validation, do not use elif so all tests run
# (Some tests done by called scripts)
if test "$dir" -a "$dsOrg" != "PO"
then
  echo "** ERROR $me faulty startup argument: $args"
  echo "-P requires PO, not $dsOrg"
  rc=8
fi    #

if test "$recFm" = "U" -a "$dsOrg" != "PO"
then
  echo "** ERROR $me faulty startup argument: $args"
  echo "RECFM(U) requires DSORG(PO)"
  rc=8
fi    #

# TODO test recFm in {FB | FBA | U | VB | VBA}
# TODO lRecL numeric or ** when RECFM(U)
# TODO dsOrg in {PO | PS}
# TODO space numeric or numeric,numeric
# TODO volume null or 1/more 6 alphanum strings separated by comma

# Exit on input error
test "$rc" -a ! "$IgNoRe_ErRoR" && exit 8                        # EXIT

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Does data set exist?
if test -z "$rc"                             # only if no rc set so far
then
  $here/$existScript "$dsn"
  # Returns 0 for exist, 2 for not exist, 8 for error
  rc=$?
fi    #

# Validate/create target data set
if test $rc -eq 0
then                                                  # data set exists
  test "$debug" && echo "use existing data set $dsn"
  test "$LOG_FILE" && echo "  Use existing data set $dsn" >> $LOG_FILE

  $here/$dcbScript $pdse $pds "$dsn" "$recFm" "$lRecL" "$dsOrg"
  # Returns 0 for DCB match, 1 for other, 2 for not pds(e), 8 for error
  rc=$?
elif test $rc -eq 2
then                                          # data set does not exist
  test "$debug" && echo "allocate $dsn"
  test "$LOG_FILE" && echo "  Allocate $dsn" >> $LOG_FILE

  if test "$recFm" = "U"
  then            # library with undefined format length (load library)
    dcb="recfm(u) lrecl(0) blksize(6999)"     # 4 blocks per half-track
  else            # library with defined record format
    # TSO ALLOCATE expects RECFM letters to be blank or comma delimited
    recFm="$(echo $recFm | sed 's/./& /g;s/ $//')"
    dcb="recfm($recFm) lrecl($lRecL) blksize(0)"
  fi    #

  if test "$dsOrg" = "PS"
  then                                                     # sequential
    dsOrg="dsorg(ps)"
  elif test "$dir"
  then                                                     # PDS
    dsOrg="dir($dir) dsorg(po)"
  else                                                     # PDS/E
    dsOrg="dsntype(library) dsorg(po)"
  fi    #

  if test "$volume"
  then
    volume="volume($volume)"
  fi    #

  if test "$hide"
  then
    # trap stderr, do not show alloc command (&2), but show error (&1)
    tsocmd "allocate new da('$dsn') $dsOrg $dcb" \
      "space($space) tracks unit(sysallda) $volume" 2> /dev/null
  else
    # Do NOT trap output, user must see alloc command (&2) & error (&1)
    tsocmd "allocate new da('$dsn') $dsOrg $dcb" \
      "space($space) tracks unit(sysallda) $volume" 2>&1
  fi    #

  if test $? -eq 0
  then
    test "$debug" && echo "data set $dsn has been allocated"
    sleep 1                  # give system time to catalog the data set
    rc=0
  else
    # Error details already reported
    echo "** ERROR $me data set $dsn has not been allocated"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
    rc=8
  fi    #
fi    # data set does not exist

# If not set, set rc to 0
test -z "$rc" && rc=0

test "$debug" && echo "< $me $rc"
exit $rc
