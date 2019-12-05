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

# Submit job and wait for completion.
#
# Arguments:
# -c         (optional) cancel job if not completed in time
# -d         (optional) enable debug messages
# -t tmpdir  (optional) directory for temporary data
# -x maxRC   (optional) highest acceptable RC (inclusive), default 0
# job        full path of job to submit
#
# Expected globals:
# $debug
#
# Return code:
# 0: job completed with RC 0
# 1: job completed with an acceptable RC
# 2: job completed, but not with an acceptable RC
# 3: job ended abnormally (abend, JCL error, ...)
# 4: job did not complete in time
# 5: job purged before we could process
# 8: error

cmdScript=opercmd.rex          # operator command script
here=$(cd $(dirname $0);pwd)   # script location
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

# misc setup
_EDC_ADD_ERRNO2=1                               # show details on error
unset ENV             # just in case, as it can cause unexpected output
_cmd umask 0022                                  # similar to chmod 755

# Ensure the rc variable is null
unset rc

# Clear input variables
unset cancel
# do NOT unset TMPDIR

# Set defaults
TMPDIR=${TMPDIR:-/tmp}                                  # default: /tmp
maxRC=0

# Get startup arguments
args="$@"
while getopts t:x:cd opt
do case "$opt" in
  c)   cancel=1;;
  d)   debug="-d";;
  t)   TMPDIR="$OPTARG";;
  x)   maxRC="$OPTARG";;
  [?]) echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $(($OPTIND-1))

# Get startup arguments
job="$1"

# Input validation, do not use elif so all tests run
if test -z $(echo "$maxRC" | grep ^[[:digit:]]*$)
then
  echo "** ERROR $me $maxRC is not a valid return code"
  rc=8
fi    #

if test ! -r "$job"
then
  echo "** ERROR $me $job cannot be read"
  echo "ls -ld \"$job\""; ls -ld "$job"
  rc=8
fi    #

if test ! -d "$TMPDIR"
then
  echo "** ERROR $me $TMPDIR is not a directory"
  echo "ls -ld \"$TMPDIR\""; ls -ld "$TMPDIR"
  rc=8
fi    #

# Exit on input error
test "$rc" -a ! "$IgNoRe_ErRoR" && exit 8                        # EXIT

tmpFile=$TMPDIR/submit.$$

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Submit job using the z/OS UNIX submit command
echo "-- submit job $job"
_cmd --repl $tmpFile submit $job
# sample output
# JOB JOB03467 submitted from path '/bld/zowe/AZWE001/logs/gimzip.jcl'
test "$debug" && sed 's/^/. /' $tmpFile         # show prefixed by '. '

# Get job ID of submitted job
# job ID can be JOBxxxxx or Jxxxxxxx, depending on system settings
jobId=$(sed 's/^JOB \(J..[[:digit:]]*\) submitted.*/\1/' $tmpFile)
echo "   jobId=$jobId"
if test -z "$jobId"
then
  echo "** ERROR $me unable to determine job ID"
  cat $tmpFile
  rc=8
fi    #

rm -f $tmpFile 2>/dev/null                    # ignore possible failure

# Exit on submit error
test "$rc" -a ! "$IgNoRe_ErRoR" && exit 8                        # EXIT

# Get job name
_cmd --repl $tmpFile $here/$cmdScript $debug "\$D${jobId},CC"
# sample output of $DjobId,CC
# $HASP890 JOB(GIMZIP)    CC=(COMPLETED,RC=0)
# $HASP890 JOB(IBMUSER)   CC=(ABENDED,ABEND=(S622,U0000))
# $HASP890 JOB(TYPO)      CC=(JCLERROR)
# $HASP890 JOB(OTHRUSER)  CC=(SECURITY_FAILURE)
# $HASP890 JOB(ACTIVE)    CC=()
# $HASP003 RC=(52),D
# $HASP003 RC=(52),D JOB15635  - NO SELECTABLE ENTRIES FOUND
# $HASP003           MATCHING SPECIFICATION
test "$debug" && sed 's/^/. /' $tmpFile         # show prefixed by '. '

jobName=$(sed -n 's/.*\$HASP890 JOB(\(.*\)) *CC.*/\1/p' $tmpFile)
jobName=${jobName:-unknown}                          # default: unknown
test "$debug" && echo "jobName=$jobName"

# Wait for job to finish
echo "-- wait for job completion"
echo "   $(date 2>/dev/null)"                      # show time progress
unset jobCC noJob
for secs in 15 45 60 60 60 60 120 120 120 120 120   # wait up to 15 min
do
  _cmd sleep $secs
  echo "   $(date 2>/dev/null)"                    # show time progress
  _cmd --repl $tmpFile $here/$cmdScript $debug "\$D${jobId},CC"
  # sample output of $DjobId,CC
  # $HASP890 JOB(GIMZIP)    CC=(COMPLETED,RC=0)
  # $HASP890 JOB(IBMUSER)   CC=(ABENDED,ABEND=(S622,U0000))
  # $HASP890 JOB(TYPO)      CC=(JCLERROR)
  # $HASP890 JOB(OTHRUSER)  CC=(SECURITY_FAILURE)
  # $HASP890 JOB(ACTIVE)    CC=()
  # $HASP003 RC=(52),D
  # $HASP003 RC=(52),D JOB15635  - NO SELECTABLE ENTRIES FOUND
  # $HASP003           MATCHING SPECIFICATION
  test "$debug" && sed 's/^/. /' $tmpFile       # show prefixed by '. '

  jobCC=$(sed -n 's/.*\$HASP890 .*CC=(\(.*\))$/\1/p' $tmpFile)
  test "$debug" && echo "jobCC=$jobCC"

  if test -n "$jobCC"                       # is non-null on completion
  then
    break                                                  # LEAVE LOOP
  elif test -n "$(grep '^$HASP003 ' $tmpFile)" # still active or gone ?
  then                                   # job not / no longer on spool
    test "$debug" && echo "nojob set"
    noJob=1
    break                                                  # LEAVE LOOP
  fi    #
done    # for secs

rm -f $tmpFile 2>/dev/null                    # ignore possible failure

# Report on job completion
if test $(echo "$jobCC" | grep ^COMPLETED,RC=)
then                                                  # job completed ?
  jobRC=$(echo "$jobCC" | sed 's/COMPLETED,RC=//')
  test "$debug" && echo "jobRC=$jobRC"
  
  if test "$jobRC" -eq 0                              # completed, RC 0
  then
    test "$debug" && echo "job $jobName ($jobId) ended with CC $jobCC"
    rc=0
  elif test "$jobRC" -le $maxRC              # completed, RC acceptable
  then
    echo "-- job $jobName ($jobId) ended with CC $jobCC"
    rc=1
  else                                   # completed, RC not acceptable
    echo "** ERROR $me job $jobName ($jobId) ended with CC $jobCC"
    rc=2
  fi    #
elif test "$jobCC"                                        # abend etc ?
then
  echo "** ERROR $me job $jobName ($jobId) ended with CC $jobCC"
  rc=3
elif test -z "$noJob"                                  # still active ?
then
  test -n "$cancel" && _cmd --null $here/$cmdScript $debug "\$C${jobId}"
  echo "** ERROR $me job $jobName ($jobId) has not yet ended"
  rc=4
  if test -n "$cancel" 
  then
    _cmd --null $here/$cmdScript $debug "\$C${jobId}"
    _cmd sleep 5     # give system time to process cancel & close files
  fi    #
else                                                     # already gone 
  echo "** ERROR $me job $jobName ($jobId) purged before processing"
  rc=5
fi    # report on completion

# If not set, set rc to 0
test -z "$rc" && rc=0

test "$debug" && echo "< $me $rc"
exit $rc

