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

# Adjust install of product wile awaiting install script updates
#
# Arguments:
# -d         (optional) enable debug messages
# ZOWE|SMPE  keyword indicating which action triggers the script
#             ZOWE: install zowe.pax
#             SMPE: install smpe.pax
# PRE|POST   keyword indicating when script is invoked
#             PRE: after unpax, before install script executes
#             POST: after install script executed
# dirInput   directory where unpaxed data resides, $INSTALL_DIR
# dirOutput  - or directory holding installed data, $ZOWE_ROOT_DIR

here=$(cd $(dirname $0);pwd)
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
 IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
function _zowePRE                     # executed before zowe-install.sh
{
}    # _zowePRE

# ---------------------------------------------------------------------
function _zowePOST                    # executed after zowe-install.sh
{
}    # _zowePOST

# ---------------------------------------------------------------------
function _smpePRE                     # executed before smpe-members.sh
{
}    # _smpePRE

# ---------------------------------------------------------------------
function _smpePOST                    # executed after smpe-members.sh
{
}    # _smpePOST

# ---------------------------------------------------------------------
# --- customize a file using sed, optionally creating a new output file
#     assumes $SED is defined by caller and holds sed command string
# $1: if -x then make result executable, parm is removed when present
# $1: input file
# $2: (optional) output file, default is $1
# ---------------------------------------------------------------------
function _sed
{
unset ExEc
if test "$1" = "-x"
then                                     # make exectuable after update
  shift
  ExEc=1
fi    #

TmP=${TMPDIR:-/tmp}/$(basename $1).$$
_cmd --repl $TmP sed "$SED" $1                  # sed '...' $1 > $TmP
#test "$debug" && echo
#test "$debug" && echo "sed $SED 2>&1 $1 > $TmP"
#sed "$SED" $1 2>&1 > $TmP                       # sed '...' $1 > $TmP
_cmd mv $TmP ${2:-$1}                           # give $TmP actual name
test -n "$ExEc" && _cmd chmod a+x ${2:-$1}      # make executable
}    # _sed

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
  test "$debug" && echo "\"$@\" 2>&1 >/dev/null"
                          "$@"  2>&1 >/dev/null
elif test "$1" = "--save"
then         # stdout -> >>$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "\"$@\" 2>&1 >> $sAvE"
                          "$@"  2>&1 >> $sAvE
elif test "$1" = "--repl"
then         # stdout -> >$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "\"$@\" 2>&1 > $sAvE"
                          "$@"  2>&1 > $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "\"$@\" 2>&1"
                          "$@"  2>&1
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

# get startup arguments
while getopts d opt
do case "$opt" in
  d)   export debug="-d";;
  [?]) echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $(($OPTIND-1))

action=$1
phase=$2
dirI=$3
dirO=$4

echo "**"
echo "** WARNING: EXTERNAL OVERRIDE OF INSTALL PROCESS - $phase $action"
echo "**"

if test ! -d "$dirI"
then
  echo "** ERROR $me $dirI is not a directory"
  echo "ls -ld \"$dirI\""; ls -ld "$dirI"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test ! -d "$dirO" -a "$phase" = "POST"
then
  echo "** ERROR $me $dirO is not a directory"
  echo "ls -ld \"$dirO\""; ls -ld "$dirO"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

test "$action" = "ZOWE" -a "$phase" = "PRE"  && _zowePRE
test "$action" = "ZOWE" -a "$phase" = "POST" && _zowePOST
test "$action" = "SMPE" -a "$phase" = "PRE"  && _smpePRE
test "$action" = "SMPE" -a "$phase" = "POST" && _smpePOST

test "$debug" && echo "< $me 0"
exit 0
