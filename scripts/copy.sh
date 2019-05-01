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

# Unix-Unix copy of file or directory content, including subdirectories.
#
# Arguments:
# -p      (optional) preserve existing file attributes
# mask    what to copy, most recent used if multiple match filter
# folder  directory where to copy to, will be created if needed
# info    (optional) description
#
# Expected globals:
# $ReMoVe $IgNoRe_ErRoR $debug $LOG_FILE
#
# caller needs these RACF permits if -p is specified:
# ($0)
# TSO PE BPX.SUPERUSER        CL(FACILITY) ACCESS(READ) ID(userid)
# TSO SETR RACLIST(FACILITY) REFRESH

me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo "> $me $@"

# ---------------------------------------------------------------------
# --- show & execute command as UID 0, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $2: if $1 = --save then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _super
{
test "$debug" && echo

if test "$1" = "--null"
then         # stdout -> null, stderr -> stdout (without going to null)
  shift
  test "$debug" && echo "echo \"$@\" | su 2>&1 >/dev/null"
                         echo  "$@"  | su 2>&1 >/dev/null
elif test "$1" = "--save"
then         # stdout -> $2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "echo \"$@\" | su 2>&1 >> $sAvE"
                         echo  "$@"  | su 2>&1 >> $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "echo \"$@\" | su 2>&1"
                         echo  "$@"  | su 2>&1
fi    #
status=$?

if test $status -ne 0
then
  echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 1                               # EXIT
fi    #
}    # _super

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $2: if $1 = --save then target receiving stdout
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
then         # stdout -> $2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 >> $sAvE"
                         $@ 2>&1 >> $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "$@ 2>&1"
                         $@ 2>&1
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 1                               # EXIT
fi    #
}    # _cmd

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing

# Clear input variables
unset p fct

# Get startup arguments
while getopts p opt
do case "$opt" in
  p)   p="-p"
       fct="_super";;
  [?]) echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

# Validate input
if test -z "$1" -o -z "$2"
then
  echo "** ERROR $me missing invocation arguments $@"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# Assume we will copy a single file
unset all

# Find file/directory to process, use most recent if multiple
file=$(ls -dt $1 2>/dev/null | head -1)
test -d "$file" && all="/*"           # copy complete directory content
test "$debug" && echo file=${file}${all}

# Validate findings
# TODO test for access to all files in directory
if test ! -r "$file"
then
  echo "** ERROR $me Cannot access $3 file(s) ($basename ($1))"
  echo "ls -ld \"$file\""; ls -ld "$file"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# Create target directory
_cmd mkdir -p $2
_cmd cd $2

# Copy file(s)
test "$LOG_FILE" && echo "  Copy of ${file}${all} into $PWD" >> $LOG_FILE
# -R traverse subdirectories
# -f attempt to replace destination that cannot be opened
# -p preserve timestamps, file mode/format, owner/group, and extattr
${fct:-_cmd} cp $p -Rf ${file}${all} .

# Remove install source if requested
test "$ReMoVe" && _cmd rm -rf ${file}

test "$debug" && echo "< $me 0"
exit 0
