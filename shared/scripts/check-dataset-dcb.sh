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

# Test if DCB (RECFM, LRECL, DSORG) of data set match criteria. When
# DSORG=PO, optionally test for PDS versus PDS/E.
#
# Arguments:
# -e       (optional) data set must be PDS/E
# -p       (optional) data set must be PDS
# dsn      data set name
# recFm     record format; {FB | U | VB}
# lRecL     logical record length, use ** for RECFM(U)
# dsOrg     data set organisation; {PO | PS}
#
# Expected globals:
# $debug
#
# Return code:
# 0: data set DCB matches arguments
# 1: data set DCB does not match arguments
# 2: partitioned data set does not match PDS(E) requirement
# 8: error

me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo "> $me $@"

# Ensure the rc variable is null
unset rc

# Clear input variables
unset pds pdse

# Get startup arguments
args="$@"
while getopts ep opt
do case "$opt" in
  e)   pdse="1";;
  p)   pds="1";;
  [?]) echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

dsn="$1"
recFm="$2"
lRecL="$3"
dsOrg="$4"

# Input validation, do not use elif so all tests run
if test "$pdse" -a "$pds"
then
  echo "** ERROR $me faulty startup argument: $args"
  echo "-e mutually exclusive with -p"
  rc=8
fi    #

if test "$pdse" -a "$dsOrg" != "PO"
then
  echo "** ERROR $me faulty startup argument: $args"
  echo "-e requires PO, not $dsOrg"
  rc=8
fi    #

if test "$pds" -a "$dsOrg" != "PO"
then
  echo "** ERROR $me faulty startup argument: $args"
  echo "-p requires PO, not $dsOrg"
  rc=8
fi    #

# Exit on input error
test "$rc" -a ! "$IgNoRe_ErRoR" && exit 8                        # EXIT

# lRecL can be **; if so, convert to \*\* but keep original in $dcb
dcb="DCB($recFm $lRecL $dsOrg)"
test "$lRecL" = "**" && lRecL="\*\*"

# Get data set information
if test -z "$rc"                             # only if no rc set so far
then
  cmd="listds '$dsn' label"
  cmdOut="$(tsocmd "$cmd" 2>&1)"
  if test $? -ne 0
  then
    echo "** ERROR $me LISTDS failed"
    echo "$cmd"
    echo "$cmdOut"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
    rc=8
  fi    #
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
fi    # get data set info

# Test DCB data
if test -z "$rc"                             # only if no rc set so far
then
  # awk limits output to 1st line of DCB data, and prints word 1, 2, & 4
  #   sample output: FB 80 PO
  # grep limits output to lines that match pattern
  #   sample output: FB 80 PO
  match=$(echo "$cmdOut" \
    | awk '/^--RECFM/{f=1;next} f{f=0;print $1,$2,$4}' \
    | grep "^$recFm $lRecL $dsOrg$")

  if test -z "$match"
  then
    test "$debug" && echo "data set $dsn does not have DCB $dcb"
    rc=1
  else
    test "$debug" && echo "data set $dsn has DCB $dcb"
    test -z "$pdse$pds" && rc=0  # set rc only if no pds(e) requirement
  fi    #
fi    # test DCB

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

# PDSE test
if test -z "$rc" -a "$pdse"                  # only if no rc set so far
then
  # DS1PDSE (0x08) - Data set is a PDSE or HFS data set (must be set)
  # DS1PDSEX (0x02) - HFS data set (must be unset)
  ds1smsfg_masked="$((0x$ds1smsfg & 0x0A))"
  test "$debug" && echo "DS1SMSFG & 0x0A: $ds1smsfg_masked"
  # If the masked value is 0x08 (8), the data set is PDSE
  if test "$ds1smsfg_masked" = "8"
  then
    test "$debug" && echo "data set $dsn is a PDSE"
  else
    test "$debug" && echo "data set $dsn is not a PDSE"
    rc=2
  fi    #
fi    # PDSE test

# PDS test
if test -z "$rc" -a "$pds"                   # only if no rc set so far
then
  # DS1PDSE (0x08) - Data set is a PDSE or HFS data set (must be unset)
  ds1smsfg_masked="$((0x$ds1smsfg & 0x08))"
  test "$debug" && echo "DS1SMSFG & 0x08: $ds1smsfg_masked"
  # If the masked value is 0x00 (0), the data set is PDS
  if test "$ds1smsfg_masked" = "0"
  then
    test "$debug" && echo "data set $dsn is a PDS"
  else
    test "$debug" && echo "data set $dsn is not a PDS"
    rc=2
  fi    #
fi    # PDS test

# If not set, set rc to 0
test -z "$rc" && rc=0

test "$debug" && echo "< $(basename $0) $rc"
exit $rc
