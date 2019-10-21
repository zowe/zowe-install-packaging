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

#% package prepared product as service (++USERMOD, ++APAR, ++PTF)
#%
#% -?                 show this help message
#% -c smpe.yaml       use the specified config file
#% -d                 enable debug messages
#%
#% -c is required


# TODO ONNO add overview of changes doen by this script

maxExec=50                     # limit number of EXEC PGM per GIMDTS job
gimdtsTools=""                 # GIMDTS tools
gimdtsTools="$gimdtsTools PTF@.jcl"
gimdtsTools="$gimdtsTools PTF@FB80.jcl"
gimdtsTools="$gimdtsTools PTF@LMOD.jcl"
gimdtsTools="$gimdtsTools PTF@MVS.jcl"
gimdtsTools="$gimdtsTools RXDDALOC.rex"
gimdtsTools="$gimdtsTools RXUNLOAD.rex"
jcl=gimdts.jcl                 # GIMDTS invocation JCL
mcs=SMPMCS.txt                 # SMPMCS header
submitScript=wait-for-job.sh   # submit script
dcbScript=check-dataset-dcb.sh # script to test dcb of data set
allocScript=allocate-dataset.sh  # script to allocate data set
csiScript=get-dsn.rex          # catalog search interface (CSI) script
cfgScript=get-config.sh        # script to read smpe.yaml config data
here=$(cd $(dirname $0);pwd)   # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- create sysmod header (PTF/APAR/USERMOD)
#
# ++PTF(UO64071)    /* 5698-ZWE00-AZWE001 */.
# ++VER(Z038,C150,P115) FMID(AZWE001)
#   SUP(IO00204,IO00869,UO61806)
#  /*
#   PROBLEM DESCRIPTION(S):
#     IO00204 -
#       PROBLEM SUMMARY:
#       ****************************************************************
#       * USERS AFFECTED: ...                                          *
#       ****************************************************************
#       * PROBLEM DESCRIPTION: ...                                     *
#       ****************************************************************
#       ...
#
#     IO00869 -
#       PROBLEM SUMMARY:
#       ****************************************************************
#       * USERS AFFECTED: ...                                          *
#       ****************************************************************
#       * PROBLEM DESCRIPTION: ...                                     *
#       ****************************************************************
#       ...
#
#   COMPONENT:
#     5698-ZWE00-AZWE001
#
#   APARS FIXED:
#     IO00204
#     IO00869
#
#   SPECIAL CONDITIONS:
#     ACTION:
#       ****************************************************************
#       * Affected function: ...                                       *
#       ****************************************************************
#       * Description: ...                                             *
#       ****************************************************************
#       * Timing: post-APPLY                                           *
#       ****************************************************************
#       * Part: ...                                                    *
#       ****************************************************************
#       ...
#
#     ACTION:
#       ****************************************************************
#       * Affected function: ...                                       *
#       ****************************************************************
#       * Description: ...                                             *
#       ****************************************************************
#       * Timing: post-APPLY                                           *
#       ****************************************************************
#       * Part: ...                                                    *
#       ****************************************************************
#       ...
#
#     COPYRIGHT:
#       5698-ZWE00 COPYRIGHT Contributors to the Zowe Project. 2019
#
#   COMMENTS:
#       NONE
#  */.
# ++HOLD(UO64071) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(19271)
#   COMMENT(
#   ****************************************************************
#   * Affected function: ...                                       *
#   ****************************************************************
#   * Description: ...                                             *
#   ****************************************************************
#   * Timing: post-APPLY                                           *
#   ****************************************************************
#   * Part: ...                                                    *
#   ****************************************************************
#   ...
#   ).
# ++HOLD(UO61806) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(19137)
#   COMMENT(
#   ****************************************************************
#   * Affected function: ...                                       *
#   ****************************************************************
#   * Description: ...                                             *
#   ****************************************************************
#   * Timing: post-APPLY                                           *
#   ****************************************************************
#   * Part: ...                                                    *
#   ****************************************************************
#   ...
#   ).
# ---------------------------------------------------------------------
function _header
{
test "$debug" && echo "> _header $@"

test "$debug" && echo "< _header"
}    # _header

# ---------------------------------------------------------------------
# --- create & submit GIMDTS job
# Assumes that all parts have metadata, and all metadata has a part
# ---------------------------------------------------------------------
function _gimdts
{
test "$debug" && echo "> _gimdts $@"

echo "-- processing RELFILEs"

# prime GIMDTS JCL
_primeJCL $log/$jcl

# get data set list
# show everything in debug mode
test "$debug" && $here/$csiScript -d "${mcsHlq}.F*"
# get data set list (no debug mode to avoid debug messages)
datasets=$($here/$csiScript "${mcsHlq}.F*")
# returns 0 for match, 1 for no match, 8 for error
rc=$?
if test $rc -gt 1
then
  echo "$datasets"                       # variable holds error message
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
elif test $rc -eq 1
then
  echo "** ERROR $me ${mcsHlq}.F* does not exist"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# loop through data sets
test "$debug" && echo "for dsn in $datasets"
for dsn in $datasets
do
  # update GIMDTS JCL
  _cmd --save $log/$jcl echo "//         SET REL=$dsn"

  # is data set a load library ?
  _testDCB "$dsn" "U" "**" "PO"
  # returns 0 for DCB match, 1 for mismatch
  rc=$?
  if test "$rc" -eq 0
  then
    echo "   $dsn (lmod)"
    proc="PTF@LMOD"
  else
    # is data set FB80 ?
    _testDCB "$dsn" "FB" "80" "PO"
    # returns 0 for DCB match, 1 for mismatch
    rc=$?
    if test "$rc" -eq 0
    then
      echo "   $dsn (fb80)"
      proc="PTF@FB80"
    else
      echo "   $dsn (other)"
      proc="PTF@MVS"
    fi    # not FB80
  fi    # not LMOD

  # process all non-ALIAS members in data set
  _getMembers "$dsn"
  test "$debug" && echo "for member in $members"
  for member in $members
  do
    # did we reach max EXEC statements for current job ?
    if test $cnt -eq maxExec
    then                   # yes, submit current job and create new job
      # run the GIMDTS job
      _submit $log/$jcl

      # archive current GIMDTS job with unique name
      cnt=$(ls $log/${jcl}* | wc -l)
      _cmd mv $log/$jcl $log/$jcl.$cnt

      # create new GIMDTS job
      _primeJCL $log/$jcl
      _cmd --save $log/$jcl echo "//         SET REL=$dsn"
    fi    # new job

    # pad member name with blanks to 8 characters
    member=$(echo "$member      " | sed 's/^\(........\).*/\1/')

    # update GIMDTS JCL
    _cmd --save $log/$jcl echo "//$member EXEC PROC=$proc,MVS=$member"

    # increase EXEC counter
    let cnt=$cnt+1
  done    # for member
done    # for dsn

# run the GIMDTS job
_submit $log/$jcl

test "$debug" && echo "< _gimdts"
}    # _gimdts

# ---------------------------------------------------------------------
# --- submit job & wait on completion, with error handling
# $1: job to submit
# ---------------------------------------------------------------------
function _submit
{
test "$debug" && echo "> _submit $@"

# only interested in RC 0 so we can use _cmd for error handling
_cmd $here/$submitScript $debug $log/$jcl

#$here/$submitScript $debug $1
## returns
## 0: job completed with RC 0
## 1: job completed with an acceptable RC
## 2: job completed, but not with an acceptable RC
## 3: job ended abnormally (abend, JCL error, ...)
## 4: job did not complete in time
## 5: job purged before we could process
## 8: error
#rc=$?
#if test $rc -ne 0
#then
#  # error details already reported
#  echo "** ERROR $me script RC $rc for submit of job $1"
#  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
#fi    #

test "$debug" && echo "< _submit"
}    # _submit

# ---------------------------------------------------------------------
# --- get list of members in data set, skip aliases
# $1: data set
# ---------------------------------------------------------------------
function _getMembers
{
test "$debug" && echo "> _getMembers $@"

cmd="listds '$dsn' members"
cmdOut="$(tsocmd "$cmd" 2>&1)"
if test $? -ne 0
then
  echo "** ERROR $me LISTDS failed"
  echo "$cmd"
  echo "$cmdOut"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
test "$debug" && echo
test "$debug" && echo "$cmdOut"
# sample output:
#listds 'ZOWE.AZWE001.F1' members
#ZOWE.AZWE001.F1
#--RECFM-LRECL-BLKSIZE-DSORG
#  FB    80    32720   PO
#
#--VOLUMES--
#  U00230
#--MEMBERS--
#  ZWEMKDIR
#  ZWE1SMPE
#  ZWE2RCVE
#  ZWE3ALOC
#  ZWE4ZFS
#  ZWE5MKD
#  ZWE6DDEF
#  ZWE7APLY
#  ZWE8ACPT
#  ZZTRUE    ALIAS(ZZALIAS)

# awk limits output to MEMBERS data, and prints word 1
members=$(echo "$cmdOut" | awk '/^--MEMBERS/{f=1;next} f{print $1}')
test "$debug" && echo members=$members     # no "" to force single line

test "$debug" && echo "< _getMembers"
}    # _getMembers

# ---------------------------------------------------------------------
# --- test data set DCB, with error handling
#     sets RC 0 on match
# $1: data set name
# $2: record format; {FB | U | VB}
# $3: logical record length, use ** for RECFM(U)
# $4: data set organisation; {PO | PS}
# ---------------------------------------------------------------------
function _testDCB
{
test "$debug" && echo "> _testDCB $@"

# do not use _cmd as non-zero rc can be normal
CmD="$here/$dcbScript \"$1\" \"$2\" \"$3\" \"$4\""
test "$debug" && echo
test "$debug" && echo "$CmD"
$here/$dcbScript "$1" "$2" "$3" "$4"
# returns 0 for DCB match, 1 for other, 2 for not pds(e), 8 for error
sTaTuS=$?
if test $sTaTuS -gt 1
then
  echo "** ERROR $me '$CmD' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test "$debug" 
then 
  if test "$sTaTuS" -eq 0
  then 
    echo "< _testDCB TRUE"
  else 
    echo "< _testDCB FALSE"
  fi    #
fi    #    debug
test "$sTaTuS" -eq 0                  # MUST be last, set rc or routine
}    # _testDCB

# ---------------------------------------------------------------------
# --- prime GIMDTS JCL
# $1: target file
# ---------------------------------------------------------------------
function _primeJCL
{
test "$debug" && echo "> _primeJCL $@"

# prime GIMDTS job JCL
SED=""
SED="$SED;s:#dir:$ptf:"
SED="$SED;s:#hlq:$gimdtsHlq:"
SED="$SED;s:#job1:$gimdtsJob1:"
_cmd --repl $1 sed "$SED" $here/$jcl

# current number of JCL EXEC statements
cnt=0

test "$debug" && echo "< _primeJCL"
}    # _primeJCL

# ---------------------------------------------------------------------
# --- stage GIMDTS JCL procedures & support REXX
# ---------------------------------------------------------------------
function _tools
{
test "$debug" && echo "> _tools $@"

echo "-- staging GIMDTS support tools"

# place tools in $gimdtsHlq (no extra LLQ)
if test -z "$gimdtsVolser"
then
  _cmd $here/$allocScript $gimdtsHlq "FB" "80" "PO" "5,5"
else
  _cmd $here/$allocScript -V "$gimdtsVolser" $gimdtsHlq "FB" "80" "PO" "5,5"
fi    #
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
# Note: _cmd fails everything but RC 0

# store customized tools
if test -z "$gimdtsVolser"
then
  SED="s:#volser://*           VOL=SER=#volser,:"
else
  SED="s:#volser://            VOL=SER=$gimdtsVolser,:"
fi    #

test "$debug" && echo "for file in $gimdtsTools"
for file in $gimdtsTools
do
  _sedMVS $here/$file $gimdtsHlq
done    # for file

test "$debug" && echo "< _tools"
}    # _tools

# ---------------------------------------------------------------------
# --- stage SMP/E metadata for parts to package
# ---------------------------------------------------------------------
function _metaData
{
test "$debug" && echo "> _metaData $@"

echo "-- stage SMP/E metadata"

# create work copy of MCS
_cmd cp $here/$mcs $ptf/$mcs

# ensure csplit output goes in $ptf
_cmd cd $ptf

# split MCS in individual '++' control statements
#   csplit creates xx## files, each holding exactly 1 control statement
#   "$(($(grep -c ^++ $ptf/$mcs)-1))" counts number of ++ in column 1
#    and when wrapped in {}, it repeats the /^++/ filter x times
_cmd csplit -s $ptf/$mcs /^++/ {$(($(grep -c ^++ $ptf/$mcs)-1))}

# return to base
_cmd --null cd -

# process individual '++' control statements
unset found
test "$debug" && echo "for file in $(ls $ptf/xx*)"
for file in $(ls $ptf/xx*)
do
  test "$debug" && echo "file=$file"

  # Extract part name from definition
  # non-part definitions (e.g. ++FUNCTION) result in null string
  # sample input:
  # ++SAMP(ZWE1SMPE)     SYSLIB(SZWESAMP) DISTLIB(AZWESAMP) RELFILE(1) .
#TODO make ZWE a variable
  name=$(sed -n 's/^++[[:alpha:]]*(\(ZWE.\{1,5\}\)) .*/\1/p' $file)
  name=$(echo $name | sed 's/ *$//')            # strip trailing blanks

  statement=$(sed -n 's/^\(++[[:alpha:]]*\)(.*/\1/p' $file)
  test "$debug" && echo "$file -> $name ($statement)"

  if test -n "$name"                                # part definition ?
  then
    found=1
    # remove RELFILE keyword & save with part name as file name
    _cmd --repl $ptf/$name sed 's/ RELFILE([[:digit:]]*)//' $file
  fi    #
done    # for file

# remove work MCS & csplit output
_cmd rm -f $ptf/$mcs $ptf/xx*

if test -z "$found"
then
  echo "** ERROR $me parsing $here/$mcs did not yield MCS data"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

echo "   $(ls $ptf/ | wc -l | sed 's/ //g') MCS defintions"
test "$debug" && echo "< _metaData"
}    # _metaData

# ---------------------------------------------------------------------
# --- customize a file using sed, and store it as a member
#     assumes $SED is defined by caller and holds sed command string
# $1: input file
# $2: output data set
# ---------------------------------------------------------------------
function _sedMVS
{
MbR=$(basename $1)                               # strip directory name
MbR=${MbR%%.*}                         # keep up to first . (exclusive)
TmP=${TMPDIR:-/tmp}/$(basename $1).$$
_cmd --repl $TmP sed "$SED" $1                    # sed '...' $1 > $TmP
_cmd mv $TmP "//'$2($MbR)'"                     # move $TmP to data set
}    # _sedMVS

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is always trashed
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $1: if --repl then save stdout to $2, parms are removed when present
# $2: if $1 = --save or --repl then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _cmd2
{
test "$debug" && echo
if test "$1" = "--null"
then                                 # stdout -> null, stderr -> null
  shift
  test "$debug" && echo "\"$@\" 2>/dev/null >/dev/null"
                          "$@"  2>/dev/null >/dev/null
elif test "$1" = "--save"
then                                 # stdout -> >>$2, stderr -> null
  sAvE=$2
  shift 2
  test "$debug" && echo "\"$@\" 2>/dev/null >> $sAvE"
                          "$@"  2>/dev/null >> $sAvE
elif test "$1" = "--repl"
then                                 # stdout -> >$2, stderr -> null
  sAvE=$2
  shift 2
  test "$debug" && echo "\"$@\" 2>/dev/null > $sAvE"
                          "$@"  2>/dev/null > $sAvE
else                                 # stdout -> stdout, stderr -> null
  test "$debug" && echo "\"$@\" 2>/dev/null"
                          "$@"  2>/dev/null
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
    echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _cmd2

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
unset YAML in
# do NOT unset debug

# get startup arguments
while getopts c:i:?d opt
do case "$opt" in
  c)   YAML="$OPTARG";;
  d)   debug="-d";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

# set envvars
. $here/$cfgScript -c                         # call with shell sharing
if test $rc -ne 0
then
  # error details already reported
  echo "** ERROR $me '. $here/$cfgScript' ended with status $rc"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

mcsHlq=${HLQ}.${RFDSNPFX}.${FMID}

# show input/output details
echo "-- input:  $mcsHlq"
echo "-- output: $ptf"

# remove output of previous run
test -d $ptf && _cmd rm -rf $ptf          # always delete ptf directory
# show everything in debug mode
test "$debug" && $here/$csiScript -d "${gimdtsHlq}.**"
# get data set list (no debug mode to avoid debug messages)
datasets=$($here/$csiScript "${gimdtsHlq}.**")
# returns 0 for match, 1 for no match, 8 for error
if test $? -gt 1
then
  echo "$datasets"                       # variable holds error message
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
# delete data sets
for dsn in $datasets
do
  _cmd2 --null tsocmd "DELETE '$dsn'"
done    # for dsn

# get ready to roll
_cmd mkdir -p $ptf

# create SMP/E MCS metadata for parts to package
_metaData

# stage GIMDTS JCL procedures & support REXX
_tools

# create & submit GIMDTS job
_gimdts

# create sysmod header (PTF/APAR/USERMOD)
_header

#   _export service ptf        ptf           ${ROOT}/ptf    # output
#   _export service gimdtsHlq  gimdtsHlq     ${HLQ}.GIMDTS  # internal
#   _export service gimdtsJob1 gimdtsJob1                   # internal
#   _export service gimdtsVol  gimdtsVolser  $VOLSER        # internal


# we are done with these, clean up
_cmd cd $here                         # make sure we are somewhere else
_cmd rm -rf $mvs

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0                                                           # EXIT
