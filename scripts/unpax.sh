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

# Unpax archive.
#
# Arguments:
# mask    what to extract, most recent used if multiple match filter
# folder  directory where to extract, will be created if needed
# info    (optional) archive description
#
# Expected globals:
# $ReMoVe $IgNoRe_ErRoR $debug $LOG_FILE

me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo "> $me $@"

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

# Validate input
if test -z "$1" -o -z "$2"
then
  echo "** ERROR $me missing invocation arguments $@"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# Find archive to process, use most recent if multiple
file=$(ls -t $1 2>/dev/null | head -1)
test "$debug" && echo file=$file

# Validate findings
if test ! -f "$file" -o ! -r "$file"
then
  echo "** ERROR $me Cannot access $3 archive ($basename ($1))"
  echo "ls -ld \"$file\""; ls -ld "$file"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# Create target directory
_cmd mkdir -p $2
_cmd cd $2

# Extract archive
test "$LOG_FILE" && echo "  Unpax of $file into $PWD" >> $LOG_FILE
_cmd pax -r -px -f $file

# Remove install source if requested
test "$ReMoVe" && _cmd rm -f $file

test "$debug" && echo "< $me 0"
exit 0
