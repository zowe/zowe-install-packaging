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

#% Start Zowe server started task.
#%
#% Invocation arguments:
#% -?            show this help message
#% -c zowe.yaml  start server using the specified input file
#% -d            enable debug messages
#%
#% If -c is not specified, then the server is started using default
#% values.

here=$(dirname $0)             # script location
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
# --- display script usage information
# ---------------------------------------------------------------------
function _displayUsage
{
echo " "
echo " $(basename $0)"
sed -n 's/^#%//p' $(whence $0)
echo " "
}    # _displayUsage

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing
export _EDC_ADD_ERRNO2=1                        # show details on error

echo
echo "-- $me -- $(sysvar SYSNAME) -- $(date)"
echo "-- startup arguments: $@"

# Clear input variables
# do NOT unset debug ZOWE_CFG

# Get startup arguments
while getopts c:d? opt
do case "$opt" in
  c)   export ZOWE_CFG="$OPTARG";;
  d)   export debug="-d";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

# No install/configuration, only runtime (used by zowe-set-envvars.sh)
unset inst conf

# Set all required environment variables
# NOTE: script exports environment vars, so run in current shell
_cmd . $(dirname $0)/../scripts/zowe-set-envvars.sh $0

# Start server
if test -z "$ZOWE_JOBCARD1"
then                                     # issue START operator command
  _cmd $scripts/opercmd.rex $debug \
    "S $ZOWE_STC_ZOWE,HOME='$ZOWE_ROOT_DIR',CFG='$ZOWE_CFG'"
else                                     # submit job
  # substitute &SYSUID. with user ID
  ZOWE_JOBCARD1=$(echo $ZOWE_JOBCARD1 | sed "s/&SYSUID\./$(id -un)/")
  test "$debug" && echo "ZOWE_JOBCARD1=$ZOWE_JOBCARD1"

  # Add job name to job card if none provided
  # sed will grab all non-blank characters from column 3 to first blank
  test -z "$(echo $ZOWE_JOBCARD1 | sed 's/..\([^ ]*\).*/\1/')" && \
    ZOWE_JOBCARD1=$(echo $ZOWE_JOBCARD1 \
    | awk -v label=$ZOWE_STC_ZOWE '{printf "//%-8s JOB %s/n",label,$3}')
  test "$debug" && echo "ZOWE_JOBCARD1=$ZOWE_JOBCARD1"

  # Create and submit job
  cat <<EOF 2>&1 > submit
${ZOWE_JOBCARD1}
${ZOWE_JOBCARD2:-//*}
//         JCLLIB ORDER=${ZOWE_HLQ}.SZWESAMP
//*
//ZOWESVR  EXEC PROC=${ZOWE_STC_ZOWE},PRM=,
// HOME='${ZOWE_ROOT_DIR}',
//  CFG='${ZOWE_CFG}'
//*
EOF

  sTaTuS=$?
  if test $sTaTuS -ne 0
  then
    echo "** ERROR $me 'submit' ended with status $sTaTuS"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
fi    #

test "$debug" && echo "< $me 0"
exit 0
