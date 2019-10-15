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

#% stage Zowe product for SMP/E packaging
#%
#% -?                 show this help message
#% -a alter.sh        execute script before install to alter setup
#%                    ignored when -i is specified
#% -c smpe.yaml       use the specified config file
#% -d                 enable debug messages
#% -f fileCount       expected number of input (build output) files
#%                    ignored when -i is specified
#% -i inputReference  file holding input names (build output archives)
#%                    mutualy exclusive with -p
#% -p inputDir        pre-installed input for this script        #debug
#%                    mutualy exclusive with -i
#%
#% either -i or -p is required
#% -c is required
#%
#% caller needs these RACF permits:
#% ($0)
#% TSO PE BPX.SUPERUSER        CL(FACILITY) ACCESS(READ) ID(userid)
#% (zowe-install-zlux.sh)
#% TSO PE BPX.FILEATTR.PROGCTL CL(FACILITY) ACCESS(READ) ID(userid)
#% TSO SETR RACLIST(FACILITY) REFRESH

# -p is intended for testing the rest of the pipeline without re-install
# -a is intended for temporary updates to the product before install
#    alterScript must accept these invocation arguments:
#      -d           (optional) enable debug messages
#      PROD | SMPE  keyword indicating which install must be updated
#      dir          directory where product install files reside
#    alterScript must return RC 0 on success, non-zero on failure

# creates $stage          directory with installed product
# creates $mvsI.*         hlq with installed product
# creates $log/*.log      product install log                       #*/
# removes old install.log files

#..Assumes that if there are multiple input pax files, they all share
#. the same leading directory, e.g. zowe-1.1.0.

smpeFilter="/smpe"             # regex to find SMP/E archive name
prodScript=install/zowe-install.sh  # product install script
smpeScript=smpe-members.sh     # SMP/E-member install script
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
for f in $(cat $in)
do
  test "$debug" && echo "$in references $f"

  # does referenced file exist?
  if test ! -f "$f" -o ! -r "$f"
  then
    _displayUsage
    echo "** ERROR $me -r $in references faulty input: $f"
    echo "ls -ld \"$f\""; ls -ld "$f"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #

  # remember name of referenced file (keep smpe and pax separate)
  if test "$(echo $f | grep $smpeFilter)"
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
  echo "** ERROR $me $count files must be listed in $in"
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
test "$alter" && _cmd $alter $debug PROD $extract

# set up yaml
echo "-- Updating yaml file"
CI_ZOWE_CONFIG_FILE=$extract/install/zowe-install.yaml
sed -e "/^install:/,\$s#rootDir=.*\$#rootDir=$stage#" \
  "${CI_ZOWE_CONFIG_FILE}" \
  > "${CI_ZOWE_CONFIG_FILE}.tmp"
mv "${CI_ZOWE_CONFIG_FILE}.tmp" "${CI_ZOWE_CONFIG_FILE}"
cat ${CI_ZOWE_CONFIG_FILE}

# install product
echo "-- installing product in $stage & $mvsI"
opts=""
opts="$opts -I"                                # Install only - no config
#opts="$opts -R"                                # remove input when done
#opts="$opts -i $stage"                         # target directory
#opts="$opts -h $mvsI"                          # target HLQ
#opts="$opts -f $log/$logFile"                  # install log
# FIXME: since the installation will update .zowe_profile, to avoid affecting
#        existing installation of Zowe, we backup .zowe_profile and restore
#        later. - jack
# Question, if the installation failed and exit, will the backup be restored?
rm -fr ~/.zowe_profile_smpe_packaging_backup
if [ -f ~/.zowe_profile ]; then
  mv ~/.zowe_profile ~/.zowe_profile_smpe_packaging_backup
fi
_cmd $extract/$prodScript $opts </dev/null
if [ -f ~/.zowe_profile_smpe_packaging_backup ]; then
  mv ~/.zowe_profile_smpe_packaging_backup ~/.zowe_profile
fi

#For debug
ls -al $stage

# TODO - what is the purpose of this - it doesn't check the install at all?
# verify everything is installed
# echo "-- verifying product install"
# orphan=$(find $extract ! -type d)
# if test "$orphan"
# then
#   echo "** ERROR $me not all files are moved to $stage or $mvsI"
#   echo "$orphan"                          # quotes preserve line breaks
#   test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
# fi    #

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
test "$alter" && _cmd $alter $debug SMPE $extract

# install SMP/E members for product
echo "-- installing SMP/E members in $stage & $mvsI"
opts=""
opts="$opts -R"                                # remove input when done
opts="$opts -c $YAML"                          # config data
opts="$opts -s $here/$cfgScript"               # script to read config
opts="$opts -f $log/$logFile"                  # install log
_cmd $extract/$smpeScript $debug $opts

# verify everything is installed
echo "-- verifying SMP/E member install"
orphan=$(find $extract ! -type d)
if test "$orphan"
then
  echo "** ERROR $me not all files are moved to $stage or $mvsI"
  echo "$orphan"                          # quotes preserve line breaks
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

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
  test "$debug" && echo "echo \"$@\" | su 2>&1 >/dev/null"
                         echo  "$@"  | su 2>&1 >/dev/null
elif test "$1" = "--save"
then         # stdout -> >>$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "echo \"$@\" | su 2>&1 >> $sAvE"
                         echo  "$@"  | su 2>&1 >> $sAvE
elif test "$1" = "--repl"
then         # stdout -> >$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "echo \"$@\" | su 2>&1 > $sAvE"
                         echo  "$@"  | su 2>&1 > $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "echo \"$@\" | su 2>&1"
                         echo  "$@"  | su 2>&1
fi    #
status=$?

if test $status -ne 0
then
    echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _super

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
  test "$debug" && echo "$@ 2>/dev/null >/dev/null"
                         $@ 2>/dev/null >/dev/null
elif test "$1" = "--save"
then                                 # stdout -> >>$2, stderr -> null
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>/dev/null >> $sAvE"
                         $@ 2>/dev/null >> $sAvE
elif test "$1" = "--repl"
then                                 # stdout -> >$2, stderr -> null
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>/dev/null > $sAvE"
                         $@ 2>/dev/null > $sAvE
else                                 # stdout -> stdout, stderr -> null
  test "$debug" && echo "$@ 2>/dev/null"
                         $@ 2>/dev/null
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
unset alter YAML count in preInst
# do NOT unset debug

# get startup arguments
while getopts a:c:f:i:p:?d opt
do case "$opt" in
  a)   alter="$OPTARG";;
  c)   YAML="$OPTARG";;
  d)   debug="-d";;
  f)   count="$OPTARG";;
  i)   in="$OPTARG";;
  p)   preInst="$OPTARG";;
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
  test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
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

if test "$in"
then                                          # validate reference file
  unset $preInst          # remove installed directory name if provided

  if test ! -r "$in"
  then
    _displayUsage
    echo "** ERROR $me faulty value for -i: $in"
    echo "ls -ld \"$in\""; ls -ld "$in"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
elif test ! -d "$preInst" -o ! -r "$preInst" # validate input directory
then
  _displayUsage
  echo "** ERROR $me faulty value for -p: $preInst"
  echo "ls -ld \"$preInst\""; ls -ld "$preInst"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
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
echo "-- input:         $in$preInst"      # only one has data, not both

# create log directory
_cmd mkdir -p $log

# remove output of previous run
test -d $stage && _super rm -rf $stage  # always delete stage directory
test -d $extract && _super rm -rf $extract           # same for extract
if test "$in"                     # only delete data sets on re-install
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
if test "$in"
then
  _findInput
  _install            # creates $Stage, must run before other _install*
  _installSMPE
  _installOther
  _clearLog

  # allow caller to alter product after install                  #debug
  test "$alter" && _cmd $alter $debug CONF $extract
else
  # continue testing SMP/E tooling with broken product build     #debug
  echo "-- cloning data from $preInst to $stage"
  _cmd mkdir -p $stage
  _cmd cd $preInst
  _cmd pax -rw -px * $stage/   # use pax to copy with extattr preserved
fi    #

# ensure we can access everything
_super chown -R $(id -u) $stage

# set permissions to ensure consistency
_cmd chmod -R 755 $stage

# log dir exists if somebody used our input for install, trash it
test -d $stage/log       && _cmd rm -rf $stage/log
test -d $stage/setup_log && _cmd rm -rf $stage/setup_log

# do not clean up $stage, needed by other scripts

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0                                                           # EXIT
