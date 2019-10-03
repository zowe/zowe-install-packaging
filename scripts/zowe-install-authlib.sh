#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2018, 2019
#######################################################################

# Create authlib(members).
# Called by zowe-install.sh
#
# Arguments:
# /
#
# Expected globals:
# $ReMoVe $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR

list=""     # file names include path based on $INSTALL_DIR
list="$list files/zss/LOADLIB/ZWESIS01"  # ZSS load module
space="10,2"                   # data set space allocation
here=$(cd $(dirname $0);pwd)   # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- Authlib"
test "$debug" && echo "> $me $@"
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $1: if --repl then save stdout to $2, parms are removed when present
# $2: if $1 = --save or --repl then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _cmd
{
test "$debug" && echo
if test "$1" = "--null"
then         # stdout -> null, stderr -> stdout (without going to null)
  shift
  test "$debug" && echo "$@ 2>&1 >/dev/null"
                         $@ 2>&1 >/dev/null
elif test "$1" = "--save"
then         # stdout -> >>$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 >> $sAvE"
                         $@ 2>&1 >> $sAvE
elif test "$1" = "--repl"
then         # stdout -> >$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 > $sAvE"
                         $@ 2>&1 > $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "$@ 2>&1"
                         $@ 2>&1
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _cmd

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing

# Set environment variables when not called via zowe-install.sh
if test -z "$INSTALL_DIR"
then
  # Set all required environment variables & logging
  # Note: script exports environment vars, so run in current shell
  _cmd . $(dirname $0)/../scripts/zowe-set-envvars.sh $0
else
  echo "  $(date)" >> $LOG_FILE
fi    #

dsn=${ZOWE_HLQ}.SZWEAUTH

# Validate/create target data set
$scripts/allocate-dataset.sh -e $dsn U "**" PO "$space"
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
rc=$?
if test $rc -eq 0
then                                          # data set created/exists
  # no operation
elif test $rc -eq 1
then                                       # data set exists, wrong DCB
  echo "** ERROR $me data set $dsn does not have DCB(U ** PO)"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
elif test $rc -eq 2
then                                       # data set exists, not PDS/E
  echo "** ERROR $me data set $dsn is not a PDSE"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  # error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# Copy members
for file in $list
do
  file=$INSTALL_DIR/$file

  # Validate file
  test "$debug" && echo file=$file
  if test ! -f "$file" -o ! -r "$file"
  then
    echo "** ERROR $me cannot access $file"
    echo "ls -ld \"$file\""; ls -ld "$file"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #

  # Copy file to member
  member=$(basename $file)
  member=${member%%.*}                 # keep up to first . (exclusive)
  echo "  Copy $file to $dsn($member)" >> $LOG_FILE
  # cp -X requires z/OS V2R2 UA96711, z/OS V2R3 UA96707 (August 2018)
  _cmd cp -X $file "//'$dsn($member)'"

  # Remove install source if requested
  test "$ReMoVe" && _cmd rm -f $file
done    # for file

# Remove install script if requested
test "$ReMoVe" && _cmd rm -f $0

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
exit 0
