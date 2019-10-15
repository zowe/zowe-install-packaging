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

#% (Re)Create Zowe SMP/E packaging configuration file.
#%
#% Invocation arguments:
#% -?            show this help message
#% -c smpe.yaml  use the specified config file
#% -d            enable debug messages
#% -h hlq        use the specified high level qualifier
#%               .$FMID is automatically added
#%               ignored when -c is specified
#% -r rootDir    use the specified root directory
#%               /$FMID is automatically added
#%               ignored when -c is specified
#% -v vrm        FMID 3-character version/release/modification
#%               ignored when -c is specified
#% -1 fmidChar1  first FMID character
#%               ignored when -c is specified
#% -2 fmidId     FMID 3-character ID code (position 2-4)
#%               ignored when -c is specified
#%
#% either -c or -v is required

cfgScript=get-config.sh        # script to read smpe.yaml config data
here=$(cd $(dirname $0);pwd)   # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

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
unset YAML HLQ ROOT VRM fmid1 fmid2
# do NOT unset debug

# get startup arguments
while getopts c:h:r:v:1:2:?d opt
do case "$opt" in
  c)   export YAML="$OPTARG";;
  d)   export debug="-d";;
  h)   export HLQ="$OPTARG";;
  r)   export ROOT="$OPTARG";;
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

# now we are sure $YAML is defined, delete the config file ...
test -e "$YAML" && _cmd rm -f $YAML
# ... and create with latest defaults/overrides
. $here/$cfgScript -c -v                      # call with shell sharing
if test $rc -ne 0
then
  # error details already reported
  echo "** ERROR $me '. $here/$cfgScript' ended with status $rc"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0
