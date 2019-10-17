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

#% Create SMP/E members.
#%
#% -?            show this help message
#% -c smpe.yaml  use the specified config file
#% -d            enable debug messages
#% -f logFile    write script log in the specified file
#% -R            remove source files after install               #debug
#% -s yaml.sh    script to read config file
#%
#% -c & -s are required

allocScript=scripts/allocate-dataset.sh  # script to allocate data set
here=$(cd $(dirname $0);pwd)   # script location
me=$(basename "$0")            # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- copy & customize files defined in $list to specified data set
# $1: data set low level qualifier
# $2: record format; {FB | U | VB}
# $3: logical record length, use ** for RECFM(U)
# $4: data set organisation; {PO | PS}
# $5: space in tracks; primary[,secondary]
# ---------------------------------------------------------------------
function _installMVS
{
test "$debug" && echo && echo "> _installMVS $@"

dsn="${mvsI}.$1"

# validate/create target data set
if test -z "$VOLSER"
then
  $here/$allocScript $dsn "$2" "$3" "$4" "$5"
else
  $here/$allocScript -V "$VOLSER" $dsn "$2" "$3" "$4" "$5"
fi    #
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
rc=$?
if test $rc -eq 0
then
  for file in $list
  do
    test "$debug" && echo file=$file
    if test ! -f "$file" -o ! -r "$file"
    then
      echo "** ERROR $me cannot access $file"
      echo "ls -ld \"$file\""; ls -ld "$file"
      test ! "$IgNoRe_ErRoR" && exit 8                           # EXIT
    fi    #

    # customize the file
    SED="s/\[FMID\]/$FMID/g"
    SED="$SED;s/\[YEAR\]/$year/g"
    SED="$SED;s/\[RFDSNPFX\]/$RFDSNPFX/g"
    _cmd --repl $file.new sed "$SED" $file

    # move the customized file
    mbr=$(basename $file)
    mbr=${mbr%%.*}                     # keep up to first . (exclusive)
    test "$LOG_FILE" && echo "  Copy $file to $dsn($mbr)" >> $LOG_FILE
    _cmd mv $file.new "//'$dsn($mbr)'"

    # remove install source if requested
    test "$ReMoVe" && _cmd rm -f $file
  done    # for file
elif test $rc -eq 1
then
  echo "** ERROR $me data set $dsn exists with wrong DCB"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  # Error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

test "$debug" && echo "< _installMVS"
}    # _installMVS

# ---------------------------------------------------------------------
# --- copy & customize files defined in $list to specified path
# $1: target path
# ---------------------------------------------------------------------
function _installUSS
{
test "$debug" && echo && echo "> _installUSS $@"

# create output directory
_cmd mkdir -p $1

for file in $list
do
  test "$debug" && echo file=$file
  if test ! -f "$file" -o ! -r "$file"
  then
    echo "** ERROR $me cannot access $file"
    echo "ls -ld \"$file\""; ls -ld "$file"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #

  # customize the file
  SED="s/\[FMID\]/$FMID/g"
  SED="$SED;s/\[YEAR\]/$year/g"
  SED="$SED;s/\[RFDSNPFX\]/$RFDSNPFX/g"
  _cmd --repl $file.new sed "$SED" $file

  # move the customized file
  fileName=$(basename $file)
  fileName=${fileName%%.*}             # keep up to first . (exclusive)
  test "$LOG_FILE" && echo "  Copy $file to $1/$fileName" >> $LOG_FILE
  _cmd mv $file.new $1/$fileName

  # remove install source if requested
  test "$ReMoVe" && _cmd rm -f $file
done    # for file

test "$debug" && echo "< _installUSS"
}    # _installUSS

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
# --- display script usage information
# ---------------------------------------------------------------------
function _displayUsage
{
echo " "
echo " $me"
sed -n 's/^#%//p' $(whence $0)
echo " "
}    # _displayUsage

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing

# misc setup
_EDC_ADD_ERRNO2=1                               # show details on error
unset ENV             # just in case, as it can cause unexpected output
_cmd umask 0022                                  # similar to chmod 755

echo; echo "-- $me - start $(date)"
echo "-- startup arguments: $@"

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# clear input variables
unset YAML LOG_FILE ReMoVe cfgScript
# do NOT unset debug

# get startup arguments
while getopts c:f:s:?dR opt
do case "$opt" in
  c)   YAML="$OPTARG";;
  d)   export debug="-d";;
  f)   export LOG_FILE="$OPTARG";;
  R)   ReMoVe="-R";;
  s)   cfgScript="$OPTARG";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

if test ! -x "$cfgScript"
then
  _displayUsage
  echo "** ERROR $me -s $cfgScript is not executable"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# set envvars
. $cfgScript -c                               # call with shell sharing
if test $rc -ne 0
then
  # error details already reported
  echo "** ERROR $me '. $cfgScript' ended with status $rc"
  test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
fi    #

scripts=$here/scripts
test "$debug" && scripts=$scripts

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

test "$LOG_FILE" && echo "<$(basename $0)> $@" >> $LOG_FILE
test "$LOG_FILE" && echo "  $(date)" >> $LOG_FILE

_cmd cd $here

year=$(date '+%Y')                                               # yyyy
test "$debug" && year=$year

# show input/output details
echo "-- input:      $here"
echo "-- output MVS: $mvsI"
echo "-- output USS: $ussI"

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# install SZWESAMP members
list=""     # file names include path based on $here
list="$list MVS/ZWE1SMPE.jcl"
list="$list MVS/ZWE2RCVE.jcl"
list="$list MVS/ZWE3ALOC.jcl"
list="$list MVS/ZWE4ZFS.jcl"
list="$list MVS/ZWE5MKD.jcl"
list="$list MVS/ZWE6DDEF.jcl"
list="$list MVS/ZWE7APLY.jcl"
list="$list MVS/ZWE8ACPT.jcl"
list="$list MVS/ZWEMKDIR.rex"
list="$list MVS/ZWES0LST.jcl"
list="$list MVS/ZWES1REJ.jcl"
list="$list MVS/ZWES2RCV.jcl"
list="$list MVS/ZWES3APL.jcl"
list="$list MVS/ZWES4ACP.jcl"
list="$list MVS/ZWES5RST.jcl"
_installMVS SZWESAMP "FB" "80" "PO" "10,2"

# install SZWEZFS members
list=""     # file names include path based on $here
list="$list USS/ZWESHPAX.sh"
_installUSS $ussI

# remove install script if requested
test "$ReMoVe" && _cmd rm -f $0
test "$ReMoVe" && _cmd rm -rf $scripts

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
test "$LOG_FILE" && echo "</$(basename $0)> 0" >> $LOG_FILE
exit 0
