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

# Test if dsn exists. Optionally test for (non-)SMS, and optionally
# return volume(s) in stdout.
#
# Arguments:
# -n   (optional) data set may not be SMS-managed
# -s   (optional) data set must be SMS-managed
# -v   (optional) return volume(s) in stdout
# dsn  data set name
#
# Expected globals:
# $debug
#
# Return code:
# 0: data set exists
# 1: data set does not match (non-)SMS requirement
# 2: data set does not exist
# 8: error

me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo "> $me $@"

# Ensure the rc variable is null
unset rc

# Clear input variables
unset nonSms sms volumes

# Get startup arguments
args="$@"
while getopts nsv opt
do case "$opt" in
  n)   nonSms="1";;
  s)   sms="1";;
  v)   volumes="-v";;
  [?]) echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

dsn="$1"

# Input validation, do not use elif so all tests run
if test -n "$nonSms" -a -n "$sms"
then
  echo "** ERROR $me faulty startup argument: $args"
  echo "-n mutually exclusive with -s"
  rc=8
fi    #

#if test "$volumes" -a -z "$nonSms"
#then
#  echo "** ERROR $me faulty startup argument: $args"
#  echo "-v requires -n"
#  rc=8
#fi    #

# Exit on input error
test "$rc" -a ! "$IgNoRe_ErRoR" && exit 8                        # EXIT

# Get data set information
if test -z "$rc"                             # only if no rc set so far
then
  cmd="listds '$dsn' label"
  cmdOut="$(tsocmd "$cmd" 2>&1)"
  if test $? -ne 0
  then
    noCatalog="$(echo $cmdOut | grep 'NOT IN CATALOG$')"
    if test "$noCatalog"
    then
      test "$debug" && echo "data set $dsn does not exist"
      rc=2
    else
      echo "** ERROR $me LISTDS failed"
      echo "$cmd"
      echo "$cmdOut"
      test ! "$IgNoRe_ErRoR" && exit 8                           # EXIT
    fi    #
  else
    test "$debug" && echo "data set $dsn exists"
    test "$debug" && echo "$cmdOut"
    # sample output:
    #listds 'IBMUSER.ZWE.SZWESAMP'
    #IBMUSER.ZWE.SZWESAMP
    #--RECFM-LRECL-BLKSIZE-DSORG
    #  FB    80    32720   PO
    #--VOLUMES--
    #  U00230
    #--FORMAT 1 DSCB--
    #F1 E4F0F02F2F3F0 0001 750165 000000 01 00 00 C9C2D4D6E2E5E2F24040404040
    #77004988000000 0200 C0 00 1800 0000 00 0000 82 80000005 000000 0000 0000
    #0100003200020032000B 00000000000000000000 00000000000000000000 0000000000
  fi    # tsocmd rc 0
fi    # get data set info

# Get VOLUMES data
if test -z "$rc" -a "$volumes"               # only if no rc set so far
then
  # awk limits output to 1st line of VOLUMES data, and prints all words
  #   with surplus blanks removed
  #   sample output: U00230
  volumes=$(echo "$cmdOut" | \
    awk '/^--VOLUMES/{f=1;next} f{f=0;$1=$1;print}')
  # S1=$1 prunes blanks because when you assign something to one of the
  # fields ($1), awk rebuilds the whole record by joining all fields
  # ($1, ..., $NF) with OFS (space by default), resulting a single-blank
  # delimited string.

  if test "$volumes"
  then
    echo "$volumes"
  else
    echo "** ERROR $me VOLUMES not found"
    echo "$cmd"
    echo "$cmdOut"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
    rc=8
  fi    #
fi    # get VOLUMES

# Set rc if no (non)SMS requirement
test -z "$rc" -a -z "$nonSms$sms" && rc=0    # only if no rc set so far

# Get DSCB data
if test -z "$rc"                             # only if no rc set so far
then
  # Do not quote $cmdOut, we need the data as 1 long string
  #   as side effect, this will cause the shell to expand LRECL **
  # sed will keep everything after --FORMAT 1 DSCB-- as 1 string
  #   sample output: F1 E4F0F02F2F3F0 0001 750165 000000 01 00 00...
  dscb="$(echo $cmdOut | sed -n 's/.*--FORMAT 1 DSCB-- \(.*\)/\1/p')"
  # test "$debug" && echo "DSCB1 $dscb"
  if test -z "$dscb"
  then
    echo "** ERROR $me DSCB1 not found"
    echo "$cmd"
    echo "$cmdOut"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
    rc=8
  fi    #
fi    # get DSCB

# Get DS1SMSFG flag byte (see "DFSMSdfp Advanced Services")
if test -z "$rc"                             # only if no rc set so far
then
  # DS1SMSFG - System managed storage indicators
  # sed will skip the first 77 chars, keep the next 2 and skip the rest
  #     sample output: 88
  ds1smsfg="$(echo $dscb | sed -n "s/.\{77\}\(.\{2\}\).*/\1/p")"
  test "$debug" && echo "DS1SMSFG $ds1smsfg"
  if test -z "ds1smsfg"
  then
    echo "** ERROR $me DS1SMSFG not found in DSCB1"
    echo "$cmd"
    echo "$cmdOut"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
    rc=8
  fi    #
fi    # get DS1SMSFG

# (non-)SMS test
if test -z "$rc"                             # only if no rc set so far
then
  # DS1SMSDS (0x80) - System managed data set (must be set)
  ds1smsfg_masked="$((0x$ds1smsfg & 0x80))"
  test "$debug" && echo "DS1SMSFG & 0x80: $ds1smsfg_masked"
  # If the masked value is 0x80 (128), the data set is SMS-managed
  if test "$ds1smsfg_masked" = "128"
  then
    test "$debug" && echo "data set $dsn is SMS-managed"
    test "$nonSms" && rc=1             # set rc if non-SMS was required
  else
    test "$debug" && echo "data set $dsn is not SMS-managed"
    test "$sms" && rc=1                # set rc if SMS was required
  fi    #
fi    # (non-)SMS test

# If not set, set rc to 0
test -z "$rc" && rc=0

test "$debug" && echo "< $me $rc"
exit $rc
