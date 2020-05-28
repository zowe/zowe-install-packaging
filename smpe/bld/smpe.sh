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
#% -b branch     GitHub branch used for this build
#% -B build      GitHub build number for this branch
#% -c smpe.yaml  use the specified config file
#% -d            enable debug messages
#% -E success    exit with RC 0, create file on successful completion
#% -f fileCount  expected number of input (build output) files
#% -h hlq        use the specified high level qualifier
#%               ignored when -c is specified
#% -i inputFile  reference file listing non-SMPE distribution files
#% -P            fail build if APAR/USERMOD is created instead of PTF
#% -p version    product version
#% -r rootDir    use the specified root directory
#%               ignored when -c is specified
#% -s stopAt.sh  stop before this sub-script is invoked          #debug
#% -V volume     allocate data sets on specified volume(s)
#% -v vrm        FMID 3-char version/release/modification (position 5-7)
#%               ignored when -c is specified
#% -1 fmidChar1  first FMID character (position 1)
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
#% (smpe-gimzip.sh)
#% TSO PE GIM.PGM.GIMZIP       CL(FACILITY) ACCESS(READ) ID(userid)
#% TSO SETR RACLIST(FACILITY) REFRESH

# TODO verify this permit requirement
# (zowe-install-zlux.sh)
# TSO PE BPX.FILEATTR.PROGCTL CL(FACILITY) ACCESS(READ) ID(userid)

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
  test ! "$IgNoRe_ErRoR" && exit $errorRC                        # EXIT
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
unset alter BUILD BRANCH YAML SuCcEsS count HLQ input reqPTF VERSION \
      ROOT stopAt VOLSER VRM fmid1 fmid2
# do NOT unset debug errorRC
errorRC=8  # default RC 8 on error

# get startup arguments
while getopts a:B:b:c:E:f:h:i:p:r:s:V:v:1:2:?dP opt
do case "$opt" in
  a)   export alter="$OPTARG";;
  B)   export BUILD="-B $OPTARG";;
  b)   export BRANCH="-b $OPTARG";;
  c)   export YAML="$OPTARG";;
  d)   export debug="-d";;
  E)   export SuCcEsS="$OPTARG"; export errorRC="0";; 
  f)   export count="$OPTARG";;
  h)   export HLQ="$OPTARG";;
  i)   export input="$OPTARG";;
  P)   export reqPTF="-P";;
  p)   export VERSION="-p $OPTARG";;
  r)   export ROOT="$OPTARG";;
  s)   export stopAt="$OPTARG";;
  V)   export VOLSER="$OPTARG";;
  v)   export VRM="$OPTARG";;
  1)   export fmid1="$OPTARG";;
  2)   export fmid2="$OPTARG";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit $errorRC;;                 # EXIT
  esac    # $opt
done    # getopts
shift $(($OPTIND-1))

# avoid false signal that we ended successfully
test -f "$SuCcEsS" && _cmd rm -f "$SuCcEsS"

# set envvars
. $here/$cfgScript -c -v                      # call with shell sharing
if test $rc -ne 0
then
  # error details already reported
  echo "** ERROR $me '. $here/$cfgScript' ended with status $rc"
  test ! "$IgNoRe_ErRoR" && exit $errorRC                        # EXIT
fi    #

# validate startup arguments
if test ! -f "$input"
then
  _displayUsage
  echo "** ERROR $me -i $input is not a file"
  test ! "$IgNoRe_ErRoR" && exit $errorRC                        # EXIT
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

# . . . . . . . . . . . start of fingerprint . . . . . . . . . . . . . . . . . . . . . . . .
# Generate reference hash keys of runtime files
echo "----- Generate reference hash keys of runtime files -----"

# The hash is calculated on the installed runtime directory created by smpe-install.sh above
stageDir=$ROOT/stage
binDir=$stageDir/bin 

# The scripts to do this are in the 'bin' directory
# The program to do this is in the 'files' directory
zoweVRM=`ls $ROOT/../content`  # The vrm directory (e.g. zowe-1.9.0) is the only entry under 'content'
zoweReleaseNumber=`echo $zoweVRM | sed -n 's/^zowe-\(.*\)$/\1/p'`
utilsDir=$ROOT/../content/$zoweVRM/scripts/utils 
mkdir $utilsDir/hash # create work directory
cp        $ROOT/../content/$zoweVRM/files/HashFiles.java $utilsDir/hash

# Compile the hash program and calculate the checksums of stageDir
$binDir/zowe-checksum-runtime.sh $stageDir $utilsDir/hash 

# save derived runtime hash file 
# 1. for SMP/E:  under ROOT_DIR/fingerprint
mkdir -p $stageDir/fingerprint
cp   $utilsDir/hash/RefRuntimeHash.txt $stageDir/fingerprint/RefRuntimeHash-$zoweReleaseNumber.txt 
# 2. for pax:    under ROOT in the pax file - 
# update pax file in place
unPaxDir=$utilsDir/hash/unPax
mkdir -p $unPaxDir
  echo CWD 245 is `pwd`
  saveDir=`pwd`
  cd $unPaxDir
    ls -l $ROOT.pax
    pax -ppx -rf  $ROOT.pax
    ls 
    mkdir fingerprint
    cp $stageDir/fingerprint/RefRuntimeHash-$zoweReleaseNumber.txt fingerprint
    ls fingerprint
    ls * 
    pax -w -f  $ROOT.pax *
  cd $saveDir
rm -r $unPaxDir
# end of update-pax-in-place      

# convert derived runtime hash file to ASCII and publish on JFrog
iconv -f IBM-1047 -t ISO8859-1 $utilsDir/hash/RefRuntimeHash.txt > $ROOT/../RefRuntimeHash.txt # base filename is not versioned

# Publish compiled hash program 
# cp   $utilsDir/hash/HashFiles.class    $binDir/internal  #  $stageDir/fingerprint
cp   $utilsDir/hash/HashFiles.class         $ROOT/.. # for publication on JFrog
cp   $binDir/zowe-verify-authenticity.sh    $ROOT/.. # for publication on JFrog

# verify the checksums of ROOT_DIR, to check zowe-verify-authenticity.sh
$binDir/zowe-verify-authenticity.sh 
if [[ $? -ne 0 ]]
then
  echo Exit code from zowe-verify-authenticity.sh was non-zero
  echo "---------- Contents of zowe-verify-authenticity.log ----------"
  cat ~/zowe/fingerprint/*.log  # fragile, because '-l outputPath' was not specified, so script chose location of log
else  
  echo Exit code from zowe-verify-authenticity.sh was zero
fi

# Don't continue to build the SMP/E package unless "$BUILD_SMPE" = "yes".
if [ "$BUILD_SMPE" != "yes" ]; then
  echo "[$SCRIPT_NAME] not building SMP/E package, exiting."
  exit 0
fi

# . . . . . . . . . . end of fingerprint . . . . . . . . . . . . . . . . . . . . . . . . .

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

# create downloadable archive of FMID
opts=""
_stopAt smpe-gimzip.sh $debug -c $YAML $opts
_cmd $here/smpe-gimzip.sh $debug -c $YAML $opts
# result (final): $gimzip                           # SMPE pax & readme

# create program directory (describes SMP/E install of FMID)
opts=""
_stopAt smpe-pd.sh $debug -c $YAML $opts
_cmd $here/smpe-pd.sh $debug -c $YAML $opts
# result (final): $ship               # zip with SMPE pax, readme, & PD

# create service (++PTF/++APAR/++USERMOD)
opts="$reqPTF $BRANCH $BUILD $VERSION"
_stopAt smpe-service.sh $debug -c $YAML $opts
_cmd $here/smpe-service.sh $debug -c $YAML $opts
# result (final): $ship                      # zip with sysmod & readme

#  signal that we ended successfully
test -n "$SuCcEsS" && _cmd touch "$SuCcEsS"

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0
