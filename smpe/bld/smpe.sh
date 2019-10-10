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

#% Wrapper to drive Zowe SMP/E packaging.
#%
#% Invocation arguments:
#% -?            show this help message
#% -a alter.sh   execute script before install to alter setup    #debug
#% -c smpe.yaml  use the specified config file
#% -d            enable debug messages
#% -f fileCount  expected number of input (build output) files
#% -h hlq        use the specified high level qualifier
#%               .$FMID is automatically added
#%               ignored when -c is specified
#% -i inputFile  reference file listing non-SMPE distribution files
#% -r rootDir    use the specified root directory
#%               /$FMID is automatically added
#%               ignored when -c is specified
#% -s stopAt.sh  stop before this sub-script is invoked          #debug
#% -V volume     allocate data sets on specified volume(s)
#% -v vrm        FMID 3-character version/release/modification
#%               ignored when -c is specified
#% -1 fmidChar1  first FMID character
#%               ignored when -c is specified
#% -2 fmidId     FMID 3-character ID code (position 2-4)
#%               ignored when -c is specified
#%
#% either -c or -v is required
#% -i is always required
#%
#% caller needs these RACF permits:
#% (smpe-install.sh smpe-split.sh smpe-gimzip.sh)
#% TSO PE BPX.SUPERUSER        CL(FACILITY) ACCESS(READ) ID(userid)
#% (zowe-install-zlux.sh)
#% TSO PE BPX.FILEATTR.PROGCTL CL(FACILITY) ACCESS(READ) ID(userid)
#% (smpe-gimzip.sh)
#% TSO PE GIM.PGM.GIMZIP       CL(FACILITY) ACCESS(READ) ID(userid)
#% TSO SETR RACLIST(FACILITY) REFRESH

# see smpe-install.sh for info on -a, -f, -i

cfgScript=get-config.sh        # script to read smpe.yaml config data
here=$(cd $(dirname $0);pwd)   # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- stop script if specified sub-script is about to start
# $1: sub-script name
# $@: sub script startup arguments
# ---------------------------------------------------------------------
function _stopAt
{
test "$debug" && echo && echo "> _stopAt $@"

if test "$stopAt" = "$1"
then
  echo "** INFO ending on request, next command would have been:"
  echo "$@"
  exit 0                                                         # EXIT
fi    #

test "$debug" && echo "< _stopAt"
}    # _stopAt

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
echo
echo "-- $me -- $(sysvar SYSNAME) -- $(date)"
echo "-- startup arguments: $@"

# misc setup
export _EDC_ADD_ERRNO2=1                        # show details on error
unset ENV             # just in case, as it can cause unexpected output
_cmd umask 0022                                  # similar to chmod 755

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# clear input variables
unset alter YAML count HLQ input ROOT stopAt VOLSER VRM fmid1 fmid2
# do NOT unset debug

# get startup arguments
while getopts a:c:f:h:i:r:s:V:v:1:2:?d opt
do case "$opt" in
  a)   export alter="$OPTARG";;
  c)   export YAML="$OPTARG";;
  d)   export debug="-d";;
  f)   export count="$OPTARG";;
  h)   export HLQ="$OPTARG";;
  i)   export input="$OPTARG";;
  r)   export ROOT="$OPTARG";;
  s)   export stopAt="$OPTARG";;
  V)   export VOLSER="$OPTARG";;
  v)   export VRM="$OPTARG";;
  1)   export fmid1="$OPTARG";;
  2)   export fmid2="$OPTARG";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

# set envvars
. $here/$cfgScript -c -v                      # call with shell sharing
if test $rc -ne 0
then
  # error details already reported
  echo "** ERROR $me '. $here/$cfgScript' ended with status $rc"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# validate startup arguments
if test ! -f "$input"
then
  _displayUsage
  echo "** ERROR $me -i $input is not a file"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# skip testing stopAt

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# install product in staging area
opts="-i $input"                                   # add reference file
test "$alter" && opts="$opts -a $alter"                  # add override
test "$count" && opts="$opts -f $count"              # add sanity check
_stopAt smpe-install.sh $debug -c $YAML $opts
_cmd $here/smpe-install.sh $debug -c $YAML $opts
# result (intermediate): $stage                              # USS data
# result (final): $mvsI                           # MVS & MVS SMPE data
# result (final): $ussI                                 # USS SMPE data

# split installed product in smaller chunks and pax them
opts="-i $input"                                   # add reference file
_stopAt smpe-split.sh $debug -c $YAML $opts
_cmd $here/smpe-split.sh $debug -c $YAML $opts
# result (final): $ussI                                      # pax data

# create FMID (++FUNCTION)
opts=""
_stopAt smpe-fmid.sh $debug -c $YAML $opts
_cmd $here/smpe-fmid.sh $debug -c $YAML $opts
# result (final): $HLQ                             # rel-files & SMPMCS

# create GIMZIP
opts=""
_stopAt smpe-gimzip.sh $debug -c $YAML $opts
_cmd $here/smpe-gimzip.sh $debug -c $YAML $opts
# result (final): $gimzip                           # SMPE pax & readme

# create program directory
opts=""
_stopAt smpe-pd.sh $debug -c $YAML $opts
_cmd $here/smpe-pd.sh $debug -c $YAML $opts
# result (final): $                                          #

# create service (++PTF)
opts=""
_stopAt smpe-service.sh $debug -c $YAML $opts
_cmd $here/smpe-service.sh $debug -c $YAML $opts
# result (final): $HLQ                                         # sysmod

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0
