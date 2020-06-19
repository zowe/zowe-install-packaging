#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2019, 2020
#######################################################################


#######################################################################
# FIXME: verify how this works after a formal release.
#######################################################################

#% Update service data upon promote.
#%
#% -?       show this help message
#% -d       enable debug messages
#% -g       use git command for remove of files
#% -p file  archive file with new data on promoted PTFs
#%
#% -p is required

# more definitions in main()
service=./service              # directory with service-specific files
ptfBucket=ptf-bucket.txt       # list of available PTFs
curApar=current-apar.txt       # list of additional APARs to supersede
curHold='current-hold-*.txt'   # hold info for this PTF
thisPtf=current-ptf.txt        # formatted list of current PTFs
here=$(cd $(dirname $0);pwd)   # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- convert ASCII file to EBCDIC
# $1: if -d then delete $2 before iconv, parm is removed when present
# $1: ASCII source file
# $2: EBCDIC target file
# output:
# - $2 is created if $1 exists
# ---------------------------------------------------------------------
_iconv()
{
if test "$1" = "-d"                            # delete $2 if it exists
then
  shift
  test -f "$2" && _cmd rm -f "$2"
fi    #

test -f "$1" && _cmd --save "$2" iconv -f ISO8859-1 -t IBM-1047 "$1"
}    # _iconv

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $1: if --repl then save stdout to $2, parms are removed when present
# $2: if $1 = --save or --repl then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
_cmd()
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
# --- display script usage information
# ---------------------------------------------------------------------
_displayUsage()
{
echo " "
echo " $me"
sed -n 's/^#%//p' ${here}/${me}
echo " "
}    # _displayUsage

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
main()      # dummy function to simplify program flow parsing
{
  echo
}

# misc setup
_EDC_ADD_ERRNO2=1                               # show details on error
unset ENV             # just in case, as it can cause unexpected output
_cmd umask 0022                                  # similar to chmod 755

echo; echo "-- $me - start $(date)"
echo "-- startup arguments: $@"

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# clear input variables
unset promoted git
# do NOT unset debug

# get startup arguments
while getopts p:?dg opt
do case "$opt" in
  d)   debug="-d";;
  g)   git="git";;
  p)   promoted="$OPTARG";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $(($OPTIND-1))

service="$(cd $here/$service 2>&1;pwd)"    # make this an absolute path

if test ! -f "$promoted"
then
  echo "** ERROR $me -p '$promoted' not found"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test ! -r "$promoted"
then
  echo "** ERROR $me -p '$promoted' not readable"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test ! -f "$service/$ptfBucket"
then
  echo "** ERROR $me script error, '$service/$ptfBucket' not found"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

TMPDIR=${TMPDIR:-/tmp}
TMPFILE=$TMPDIR/$me.$$

# show input/output details
echo "-- updating: $service"

# FMID promotion will have a null-sized file, no action required here
if test ! -s "$promoted"
then
  echo "-- no action, '$promoted' is a null file"
  echo "-- completed $me 0"
  test "$debug" && echo "< $me 0"
  exit 0                                                         # EXIT
fi    #

# go to service directory
_cmd cd $service

# extract new promoted data, this overwrites the existing promoted data
# (-x: extract -v: verbose, -f: tar-file)
_cmd tar -xvf $promoted

## $promoted also holds $thisPtf with name of PTF(s) being promoted,
## use it to update $ptfBucket

# file is ASCII, if it looks like garbage we are on z/OS -> convert
if test -n "$(head -1 $thisPtf | cut -c 1-7 | grep [[:cntrl:]])"
then
  for file in $(tar -tf $promoted)              # -t: table of contents
  do
    _iconv -d $file $TMPFILE
    _cmd mv $TMPFILE $file
  done    # for file
fi    # ASCII -> EBCDIC conversion

# get first PTF being promoted
ptf=$(head -1 $thisPtf 2>&1)
echo "-- marking PTF $ptf & family as used"

# comment out line with this PTF
_cmd --repl $TMPFILE sed "/$ptf/s/.*/#& - $(date)/" $service/$ptfBucket

# verify we did an update
diff $TMPFILE $service/$ptfBucket 2>&1 1> /dev/null
if test $? -eq 0
then
  # this is bad, the PTF being promoted should have come from this file
  echo "** ERROR $me $ptfBucket not updated"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# replace old $ptfBucket with new one
_cmd mv $TMPFILE $service/$ptfBucket

# clean up, these files may not exist after promote
files=$(ls $thisPtf $curApar $curHold 2> /dev/null)
test -n "$files" && _cmd $git rm -f $files

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0                                                           # EXIT
