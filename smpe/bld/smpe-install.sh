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

#% stage Zowe product for SMP/E packaging
#%
#% -?              show this help message
#% -a alter.sh     execute script before/after install to alter setup
#%                 mutualy exclusive with -I
#% -c smpe.yaml    use the specified config file
#% -d              enable debug messages
#% -f fileCount    expected number of input (build output) files
#% -H installHlq   use the specified pre-installed product install MVS
#%                 requires -I and -L to be specified
#% -i inputFile    file holding input names (build output archives)
#% -I installDir   use the specified pre-installed product install USS
#%                 requires -H and -L to be specified
#%                 mutualy exclusive with -a
#% -L install.log  use the specified pre-installed product install log
#%                 requires -H and -I to be specified
#%
#% -c and -i are required
#%
#% caller needs these RACF permits:
#% ($0)
#% TSO PE BPX.SUPERUSER        CL(FACILITY) ACCESS(READ) ID(userid)
#% (zowe-install-zlux.sh)
#% TSO PE BPX.FILEATTR.PROGCTL CL(FACILITY) ACCESS(READ) ID(userid)
#% TSO SETR RACLIST(FACILITY) REFRESH

# -H/I/L reuses an existing non-SMP/E product install
#        caller must ensure it matches the product pax mentioned in
#        -i inputFile
# -a is intended for temporary updates to the product before install
#    alterScript must accept these invocation arguments:
#      -d         (optional) enable debug messages
#      ZOWE|SMPE  keyword indicating which action triggers the script
#                  ZOWE: install zowe.pax
#                  SMPE: install smpe.pax
#      PRE|POST   keyword indicating when script is invoked
#                  PRE: after unpax, before install script executes
#                  POST: after install script executed
#      dirInput   directory where unpaxed data resides, $INSTALL_DIR
#      dirOutput  - or directory holding installed data, $ZOWE_ROOR_DIR
#    alterScript must return RC 0 on success, non-zero on failure

# creates $stage/*        directory with installed product
# creates $mvsI.*         data sets with installed product
# creates $log/*.log      product install log                       #*/
# removes old install.log files

#..Assumes that if there are multiple input pax files, they all share
#. the same leading directory, e.g. zowe-1.1.0.

# more definitions in main()
removeInstall=0                # 1 if install removes installed files
smpeFilter="/smpe"             # regex to find SMP/E archive name
fpScript=bin/zowe-verify-authenticity.sh  # product fingerprint script
prodScript=install/zowe-install.sh  # product install script
smpeScript=zowe-install-smpe.sh  # SMP/E-member install script
csiScript=get-dsn.rex          # catalog search interface (CSI) script
cfgScript=get-config.sh        # script to read smpe.yaml config data
here=$(cd $(dirname $0);pwd)   # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- find build output (input for install)
# ---------------------------------------------------------------------
function _findInput
{
test "$debug" && echo && echo "> _findInput $@"

# ensure that input names are initialy null
unset in_pax in_other in_smpe

# get name of files being referenced
for f in $(cat $input)
do
  test "$debug" && echo "$input references $f"

  # does referenced file exist?
  if test ! -f "$f" -o ! -r "$f"
  then
    _displayUsage
    echo "** ERROR $me -r $input references faulty input: $f"
    echo "ls -ld \"$f\""; ls -ld "$f"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #

  # remember name of referenced file (keep smpe and pax separate)
  if test "$(echo $f | grep "$smpeFilter")"
  then
    in_smpe="$(echo $in_smpe $f | sed 's/^ //')"
  elif test "$(echo $f | grep pax$)"
  then
    in_pax="$(echo $in_pax $f | sed 's/^ //')"
  else
    in_other="$(echo $in_other $f | sed 's/^ //')"
  fi    #
done    # for f

# ensure we have all input
if test "$count" && test $count -ne $(echo $in_pax $in_other $in_smpe | wc -w)
then
  echo "** ERROR $me $count files must be listed in $input"
  echo "(pax)   $in_pax"
  echo "(smpe)  $in_smpe"
  echo "(other) $in_other"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# show input details, lined up with input/output shown elsewhere
echo "-- input (pax):   $in_pax"
echo "-- input (smpe):  $in_smpe"
echo "-- input (other): $in_other"

test "$debug" && echo "< _findInput"
}    # _findInput

# ---------------------------------------------------------------------
# --- verify fingerprint of product runtime directory files
# ---------------------------------------------------------------------
function _checkFingerprint
{
test "$debug" && echo && echo "> _checkFingerprint $@"

# verify the fingerprints
echo "-- verify reference hash keys of $stage"
_cmdLog $stage/$fpScript -L $log/$logFile

test "$debug" && echo "< _checkFingerprint"
}    # _checkFingerprint

# ---------------------------------------------------------------------
# --- stage a pre-installed product install
# ---------------------------------------------------------------------
function _preInstalled
{
test "$debug" && echo && echo "> _preInstalled $@"

echo "-- reusing an existing install"
# 1. reuse existing log file
_cmd mv $preInstLog $log/$logFile

# 2. reuse exisiting directory structure
_cmd mv $preInstDir $stage
_cmd ls -A $stage

# 3. reuse existing data sets
for dsn in $preInstDsn
do
  LLQ=${dsn##*.}                         # keep from last . (exclusive)
  _cmd2 --null tsocmd "RENAME '${dsn}' '${mvsI}.$LLQ'"
  echo "${mvsI}.$LLQ"
done    # for dsn

test "$debug" && echo "< _preInstalled"
}    # _preInstalled

# ---------------------------------------------------------------------
# --- explode product build output & install it
# ---------------------------------------------------------------------
function _install
{
test "$debug" && echo && echo "> _install $@"

# explode pax file(s)
for f in $in_pax
do
  _explode $f $extract
done    #

# ensure we can access everything
_super chown -R $(id -u) $extract

# remember original extract location
orig=$extract

# step into possible leading dirs in archive
#..Assumes that if there are multiple input pax files, they all share
#. the same leading directory, e.g. zowe-1.1.0.
# (loop while there is only 1 entry, a sub-directory, in this directory)
while test 1 -eq $(ls $extract/ | wc -w) -a \
           1 -eq $(ls -D $extract/ | wc -w)
do
  test "$debug" && echo
  test "$debug" && echo "extract=$extract/$(ls -D $extract)"
  extract=$extract/$(ls -D $extract)
done    #

# allow caller to alter product before install                   #debug
test "$alter" && _cmd $alter $debug ZOWE PRE $extract -

# install product
echo "-- installing product in $stage & $mvsI"
echo The extract $extract contains
ls -l $extract

opts=""
opts="$opts -h $mvsI"                          # target HLQ
opts="$opts -i $stage"                         # target directory
opts="$opts -f $log/$logFile"                  # install log
test $removeInstall -eq 1 && opts="$opts -R"   # remove input when done
_cmdLog $extract/$prodScript $debug $opts </dev/null

# allow caller to alter product after install                    #debug
test "$alter" && _cmd $alter $debug ZOWE POST $extract $stage

# verify everything is installed
if test $removeInstall -eq 1
then
  echo "-- verifying product install"
  orphan=$(find $extract ! -type d)
  if test "$orphan"
  then
    echo "** ERROR $me not all files are moved to $stage or $mvsI"
    echo "$orphan"                        # quotes preserve line breaks
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
fi    # $removeInstall

# reset extract location to original and clean up
extract=$orig
_cmd rm -rf $extract

test "$debug" && echo "< _install"
}    # _install

# ---------------------------------------------------------------------
# --- explode SMP/E archive & install SMP/E members
# ---------------------------------------------------------------------
function _installSMPE
{
test "$debug" && echo && echo "> _installSMPE $@"

# explode pax file(s)
for f in $in_smpe
do
  _explode $f $extract
done    #

# ensure we can access everything
_super chown -R $(id -u) $extract

# remember original extract location
orig=$extract

# step into possible leading dirs in archive
#..Assumes that if there are multiple input pax files, they all share
#. the same leading directory, e.g. zowe-1.1.0.
# (loop while there is only 1 entry, a sub-directory, in this directory)
while test 1 -eq $(ls $extract/ | wc -w) -a \
           1 -eq $(ls -D $extract/ | wc -w)
do
  test "$debug" && echo
  test "$debug" && echo "extract=$extract/$(ls -D $extract)"
  extract=$extract/$(ls -D $extract)
done    #

# allow caller to alter product before install                   #debug
test "$alter" && _cmd $alter $debug SMPE PRE $extract -

# install SMP/E members for product
echo "-- installing SMP/E members in $stage & $mvsI"
opts=""
opts="$opts -c $YAML"                          # config data
opts="$opts -s $here/$cfgScript"               # script to read config
opts="$opts -f $log/$logFile"                  # install log
test $removeInstall -eq 1 && opts="$opts -R"   # remove input when done
_cmdLog $extract/$smpeScript $debug $opts

# allow caller to alter product after install                    #debug
test "$alter" && _cmd $alter $debug SMPE POST $extract $stage

# verify everything is installed
if test $removeInstall -eq 1
then
  echo "-- verifying SMP/E member install"
  orphan=$(find $extract ! -type d)
  if test "$orphan"
  then
    echo "** ERROR $me not all files are moved to $stage or $mvsI"
    echo "$orphan"                        # quotes preserve line breaks
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
fi    # $removeInstall

# reset extract location to original and clean up
extract=$orig
_cmd rm -rf $extract

test "$debug" && echo "< _installSMPE"
}    # _installSMPE

# ---------------------------------------------------------------------
# --- add remaining input files to installed product
# ---------------------------------------------------------------------
function _installOther
{
test "$debug" && echo && echo "> _installOther $@"

# add remaining input files to installed product (stage directory)
if test "$in_other"
then
  echo "-- adding other data to $stage"
  _cmd cp $in_other $stage/
fi    #

test "$debug" && echo "< _installOther"
}    # _installOther

# ---------------------------------------------------------------------
# --- clear old install logs
# ---------------------------------------------------------------------
function _clearLog
{
test "$debug" && echo && echo "> _clearLog $@"

# get names of all saved install logs except the last x
echo "-- remove old install logs"
prev=$(ls $log/${mask}.*.${tail} \
         | awk -v n=$hist '{if(NR>n) print a[NR%n]; a[NR%n]=$0}')
test "$debug" && echo prev=$prev

# remove oldest logs to preserve space
test "$prev" && _cmd rm -f $prev

test "$debug" && echo "< _clearLog"
}    # _clearLog

# ---------------------------------------------------------------------
# --- expand archive
# $1: if --del then delete archive after explode, parm is removed
# $1: input file
# $2: output directory (created if it does not exist)
# ---------------------------------------------------------------------
function _explode
{
test "$debug" && echo && echo "> _explode $@"

unset DEL
# delete archive after explode ?
if test "$1" = "--del"
then
  shift
  DEL=1
fi    #

# go to target directory, create it if it does not exist
_cmd mkdir -p $2
_cmd cd $2

# give a heads up
total=$(pax -f "$1" | wc -l | sed 's/ //g')
echo "-- exploding $total entries from $1 to $2"

# explode pax
# pax
#  -f "$pax_file"      pax file
#  -r                  read (extract)
#  -px                 preserve extended attributes
## -v                  verbose
paxOpt="-r -px -f $1"
#paxOpt="-v $paxOpt"                                             #debug
_super pax $paxOpt

# delete input file if requested
test "$DEL" && _cmd rm -f $1

# return to previous directory
_cmd --null cd -

test "$debug" && echo "< _explode"
}    # _explode

# ---------------------------------------------------------------------
# --- _cmd(), plus show $log/$logFile on error
# $@: see _cmd()
# ---------------------------------------------------------------------
function _cmdLog
{
# remember and remove IgNoRe_ErRoR
unset SeT_IgNoRe_ErRoR
test -n "$IgNoRe_ErRoR" && SeT_IgNoRe_ErRoR=$IgNoRe_ErRoR
unset IgNoRe_ErRoR

# execute command
_cmd $@

# restore IgNoRe_ErRoR and show log on error
test -n "$IgNoRe_ErRoR" && IgNoRe_ErRoR=$SeT_IgNoRe_ErRoR
if test $sTaTuS -ne 0
then
  echo "install log $log/$logFile:"
  cat $log/$logFile | sed 's/^/: /' 2>&1
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _cmdLog

# ---------------------------------------------------------------------
# --- show & execute command as UID 0, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $1: if --repl then save stdout to $2, parms are removed when present
# $2: if $1 = --save or --repl then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _super
{
test "$debug" && echo

if test "$1" = "--null"
then         # stdout -> null, stderr -> stdout (without going to null)
  shift
  test "$debug" && echo "echo \"$@\" | su 2>&1 1>/dev/null"
                         echo  "$@"  | su 2>&1 1>/dev/null
elif test "$1" = "--save"
then         # stdout -> >>$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "echo \"$@\" | su 2>&1 1>>$sAvE"
                         echo  "$@"  | su 2>&1 1>>$sAvE
elif test "$1" = "--repl"
then         # stdout -> >$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "echo \"$@\" | su 2>&1 1>$sAvE"
                         echo  "$@"  | su 2>&1 1>$sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "echo \"$@\" | su 2>&1"
                         echo  "$@"  | su 2>&1
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _super

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is trapped and only shown on error
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $1: if --repl then save stdout to $2, parms are removed when present
# $2: if $1 = --save or --repl then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _cmd2
{
sTdErRsAvE=${TMPDIR:-/tmp}/$me.cmd.stderr.$RANDOM
test "$debug" && echo
if test "$1" = "--null"
then                                  # stdout -> null, stderr -> saved
  shift
  test "$debug" && echo "\"$@\" 2>$sTdErRsAvE 1>/dev/null"
                          "$@"  2>$sTdErRsAvE 1>/dev/null
elif test "$1" = "--save"
then                                  # stdout -> >>$2, stderr -> saved
  sAvE=$2
  shift 2
  test "$debug" && echo "\"$@\" 2>$sTdErRsAvE 1>>$sAvE"
                          "$@"  2>$sTdErRsAvE 1>>$sAvE
elif test "$1" = "--repl"
then                                  # stdout -> >$2, stderr -> saved
  sAvE=$2
  shift 2
  test "$debug" && echo "\"$@\" 2>$sTdErRsAvE 1>$sAvE"
                          "$@"  2>$sTdErRsAvE 1>$sAvE
else                                  # stderr -> saved
  test "$debug" && echo "\"$@\" 2>$sTdErRsAvE"
                          "$@"  2>$sTdErRsAvE
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** ERROR $me '$@' ended with status $sTaTuS"
  cat $sTdErRsAvE | sed 's/^/: /' 2>&1
  rm -f sTdErRsAvE
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  rm -f sTdErRsAvE
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
  test "$debug" && echo "\"$@\" 2>&1 1>/dev/null"
                          "$@"  2>&1 1>/dev/null
elif test "$1" = "--save"
then         # stdout -> >>$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "\"$@\" 2>&1 1>>$sAvE"
                          "$@"  2>&1 1>>$sAvE
elif test "$1" = "--repl"
then         # stdout -> >$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "\"$@\" 2>&1 1>$sAvE"
                          "$@"  2>&1 1>$sAvE
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
export _EDC_ADD_ERRNO2=1                        # show details on error
# .profile with ENV=script with echo -> echo is in stdout (begin)
# ensure that newly created files are in EBCDIC codepage
unset ENV _CEE_RUNOPTS _TAG_REDIR_IN _TAG_REDIR_OUT _TAG_REDIR_ERR
export _BPXK_AUTOCVT="OFF"
_cmd umask 0022                                  # similar to chmod 755

echo; echo "-- $me - start $(date)"
echo "-- startup arguments: $@"

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# clear input variables
unset alter YAML count preInstHlq input preInstDir preInstLog
# do NOT unset debug

# get startup arguments
while getopts a:c:f:H:i:I:L:?d opt
do case "$opt" in
  a)   alter="$OPTARG";;
  c)   YAML="$OPTARG";;
  d)   debug="-d";;
  f)   count="$OPTARG";;
  H)   preInstHlq="$OPTARG";;
  i)   input="$OPTARG";;
  I)   preInstDir="$OPTARG";;
  L)   preInstLog="$OPTARG";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $(($OPTIND-1))

# set envvars
. $here/$cfgScript -c                         # call with shell sharing
if test $rc -ne 0
then
  # error details already reported
  echo "** ERROR $me '. $here/$cfgScript' ended with status $rc"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test -n "$alter" -a -n "$preInstDir"
then
  _displayUsage
  echo "** ERROR $me -a and -I are mutually exclusive"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test "$(echo $count | sed 's/[[:digit:]]//g')"
then
  _displayUsage
  echo "** ERROR $me faulty value for -f: $count"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test "$alter"
then
  if test ! -x "$alter"
  then
    echo "** ERROR $me -a $alter is not executable"
    echo "ls -ld \"$alter\""; ls -ld "$alter"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
fi    #

if test ! -r "$input"
then
  _displayUsage
  echo "** ERROR $me faulty value for -i: $input"
  echo "ls -ld \"$input\""; ls -ld "$input"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test "$preInstHlq"
then
  if test -z "$preInstDir" -o -z "$preInstLog"
  then
    _displayUsage
    echo "** ERROR $me -H requires -I and -L"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #

  # show everything in debug mode
  test "$debug" && $here/$csiScript -d "$preInstHlq.**"
  # get data set list (no debug mode to avoid debug messages)
  preInstDsn=$($here/$csiScript "$preInstHlq.**")
  # returns 0 for match, 1 for no match, 8 for error
  if test $? -gt 1
  then
    _displayUsage
    echo "** ERROR $me faulty value for -p: $preInstDir"
    echo "$preInstDsn"                   # variable holds error message
    preInstDsn=''                      # in case we continue processing
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
else
  unset preInstDsn  # to be safe
fi    #

if test "$preInstDir"
then
  if test -z "$preInstHlq" -o -z "$preInstLog"
  then
    _displayUsage
    echo "** ERROR $me -I requires -H and -L"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #

  if test ! -d "$preInstDir" -o ! -r "$preInstDir"
  then
    _displayUsage
    echo "** ERROR $me faulty value for -p: $preInstDir"
    echo "ls -ld \"$preInstDir\""; ls -ld "$preInstDir"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
fi    #

if test "$preInstLog"
then
  if test -z "$preInstHlq" -o -z "$preInstDir"
  then
    _displayUsage
    echo "** ERROR $me -L requires -H and -I"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #

  if test ! -r "$preInstLog"
  then
    _displayUsage
    echo "** ERROR $me faulty value for -p: $preInstLog"
    echo "ls -ld \"$preInstLog\""; ls -ld "$preInstLog"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
fi    #

# validate envvars (inherited or set by -c)
if test -z "$VRM"
then
  _displayUsage
  echo "** ERROR $me -c is required"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

mask="install"                                       # install log ID
date=$(date '+%Y%m%d_%H%M%S')                        # yyyymmdd_hhmmss
tail='log'
logFile=${mask}.${date}.${tail}                      # install log name

# show input/output details, lined up with input/output shown elsewhere
echo "-- output USS:    $stage"
echo "-- output MVS:    $mvsI"
echo "-- input:         $input"
test "$preInstDir" && echo "-- input exist:   $preInstDir"

# create log directory
_cmd mkdir -p $log

# remove output of previous run
test -d $stage && _super rm -rf $stage  # always delete stage directory
test -d $extract && _super rm -rf $extract           # same for extract
if test -z "$preInstDir"            # only delete data sets on new install
then
  # show everything in debug mode
  test "$debug" && $here/$csiScript -d "${mvsI}.**"
  # get data set list (no debug mode to avoid debug messages)
  datasets=$($here/$csiScript "${mvsI}.**")
  # returns 0 for match, 1 for no match, 8 for error
  if test $? -gt 1
  then
    echo "$datasets"                     # variable holds error message
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
  # delete data sets
  for dsn in $datasets
  do
    _cmd2 --null tsocmd "DELETE '$dsn'"
  done    # for dsn
fi    # delete data sets

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# stage data
_findInput
# 1. product install - creates $stage, must run before other _install*
if test -z "$preInstDir"
then
  _install
else
  _preInstalled
fi    #
_checkFingerprint         # must be on a clean product install, no SMPE
# 2. add SMP/E files & members to product install
_installSMPE
# 3. add optional other files to product install
_installOther

# clean up on repeated builds
_clearLog

# ensure we can access everything
_super chown -R $(id -u) $stage

# set permissions to ensure consistency & ability to move during split
_cmd chmod -R 755 $stage

# remove install log and possible other logs
logDirs="$(ls -d $stage/*log 2>/dev/null)"
test -n "$logDirs" && _cmd rm -rf "$logDirs"

# show root dir in build log to simplify debugging SMPE input issues
test $debug && _cmd ls -l $stage

# do not clean up $stage, needed by other scripts

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0                                                           # EXIT
