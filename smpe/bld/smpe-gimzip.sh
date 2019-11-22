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

#% package base FMID (++FUNCTION) for shipment in GIMZIP format
#%
#% -?                 show this help message
#% -c smpe.yaml       use the specified config file
#% -d                 enable debug messages
#%
#% -c is required
#%
#% caller needs these RACF permits:
#% ($0)
#% TSO PE BPX.SUPERUSER        CL(FACILITY) ACCESS(READ) ID(userid)
#% TSO PE GIM.PGM.GIMZIP       CL(FACILITY) ACCESS(READ) ID(userid)
#% TSO SETR RACLIST(FACILITY) REFRESH

# creates $gimzip                directory with pax & readme (ASCII)
# creates $log/$jcl              gimzip JCL
# creates $log/$smpout           gimzip DD smpout output
# creates $log/$sysprint         gimzip DD sysprint output
# creates $log/$extractSize      required zFS size saved for usage in PD
# creates $log/$FMID.readme.txt  readme (EBCDIC)

product='Zowe Open Source Project'  # product name (max. 67 chars)
#        ----+----1----+----2----+----3----+----4----+----5----+----6----+--
jcl=gimzip.jcl                 # GIMZIP invocation JCL
readme=gimzip.readme.txt       # generic GIMZIP readme file
extractSize=gimunzip-size.txt  # save required zFS size for PD creation
smpout=gimzip.smpout.log       # GIMZIP SMPOUT log
sysprint=gimzip.sysprint.log   # GIMZIP SYSPRINT log
sysinGimzip=sysin.gimzip       # generated SYSIN for GIMZIP
sysinGimunzip=sysin.gimunzip   # generated SYSIN for GIMUNZIP
csiScript=get-dsn.rex          # catalog search interface (CSI) script
submitScript=wait-for-job.sh   # submit script
sizeScript=gimunzip-size.rex   # script to calculate size of extract zFS
existScript=check-dataset-exist.sh  # script to test if data set exists
allocScript=allocate-dataset.sh  # script to allocate data set
cfgScript=get-config.sh        # script to read smpe.yaml config data
here=$(cd $(dirname $0);pwd)   # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- invoke GIMZIP to create pax files & metadata for SMPMCS & RELFILEs
# $1: GIMZIP output directory
#
# GIMZIP is created for MVS batch invocation. We are using JCL to 
# create this environment.
#
# documentation in "SMP/E for z/OS Reference (SA23-2276)" and
# "IBM Developer for z Systems Host Configuration Guide (SC27-8577)"
#
# user must be authorized to use this utility:
# - SYS1.MIGLIB(GIMZIP) packaging service routine
# ---------------------------------------------------------------------
function _gimzip
{
test "$debug" && echo && echo "> _gimzip $@"

echo "-- preparing GIMZIP"

# create metadata describing what GIMZIP & GIMUNZIP must process
_gimzipMeta

# simplify JCL customization by using 1 root path for all directories
# KEEP IN SYNC WITH $here/$jcl
_ln $SMPCPATH $scratch/SMPCPATH
_ln $SMPJHOME $scratch/SMPJHOME
_ln $1        $scratch/SMPDIR
_cmd mkdir -p $scratch/SMPWKDIR

# allocate & populate data sets used by GIMZIP
# note: GIMZIP assumes FB80 for SYSIN and will abend if this is not so
# note: GIMZIP assumes FBA121 for output and does not write \n, so
# writing directly to a USS file results in all output on a single line
# KEEP IN SYNC WITH $here/$jcl
_alloc "${gimzipHlq}.SMPOUT"   "FBA" "121" "PS" "1,1"
_alloc "${gimzipHlq}.SYSPRINT" "FBA" "121" "PS" "1,1"
_alloc "${gimzipHlq}.SYSIN"    "FB"   "80" "PS" "1,1"
_cmd cp $scratch/$sysinGimzip "//'${gimzipHlq}.SYSIN'"

# do we have volser defined?
if test -z "$gimzipVolser" 
then
  volser='//*'                                           # comment line
else  
  volser="// VOL=SER=($gimzipVolser),"    # () for multi-volume support
fi    #

# create GIMZIP JCL
echo "-- creating GIMZIP job"
echo "   job1    ='$gimzipJob1'"
echo "   parm    ='$gimzipParm'"
echo "   volser  ='$volser'"
echo "   HLQ     ='$gimzipHlq'"
echo "   DIR     ='$scratch'"
echo "   SMPJHOME='$JAVA_HOME'"
echo "   SMPCPATH='$SMP_HOME/classes'"

SED="s:#job1:$gimzipJob1:"
SED="$SED;s:#parm:$gimzipParm:"
SED="$SED;s:#hlq:$gimzipHlq:"
SED="$SED;s:#volser:$volser:"
SED="$SED;s:#dir:$scratch:"
_sed $here/$jcl $log/$jcl
test "$debug" && cat $log/$jcl

# run the GIMZIP job
$here/$submitScript $debug $log/$jcl
# returns
# 0: job completed with RC 0
# 1: job completed with an acceptable RC
# 2: job completed, but not with an acceptable RC
# 3: job ended abnormally (abend, JCL error, ...)
# 4: job did not complete in time
# 5: job purged before we could process
# 8: error
gimzipRC=$?

# give z/OS time to free the data sets before accessing them again
# cp: FSUM6258 cannot open file "//'...'": EDC5061I An error occurred 
# when attempting to define a file to the system. (errno2=0xC00B0403)
_cmd sleep 1

# save GIMZIP output in log directory
_cmd cp "//'${gimzipHlq}.SYSPRINT'" $log/$sysprint
_cmd cp "//'${gimzipHlq}.SMPOUT'" $log/$smpout

# did GIMZIP fail ?
if test $gimzipRC -gt 0
then                                       # GIMZIP failure
  test "$debug" && echo "GIMZIP failure"
  echo "-- $sysprint $(cat $log/$sysprint | wc -l) line(s)"
  sed 's/^/. /' $log/$sysprint                # show prefixed with '. '
  echo "-- $smpout $(cat $log/$smpout | wc -l) line(s)"
  sed 's/^/. /' $log/$smpout                  # show prefixed with '. '
  echo "** ERROR $me GIMZIP ended with a non-zero return code"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else                                                   # GIMZIP success
  if test "$debug"
  then
    echo "-- $sysprint $(cat $log/$sysprint | wc -l) line(s)"
    sed 's/^/. /' $log/$sysprint              # show prefixed with '. '
    echo "-- $smpout $(cat $log/$smpout | wc -l) line(s)"
    sed 's/^/. /' $log/$smpout                # show prefixed with '. '
  fi    #
  echo "   GIMZIP successful"
fi    #

test "$debug" && echo "< _gimzip"
}    # _gimzip

# ---------------------------------------------------------------------
# --- create SYSIN metadata for GIMZIP & GIMUNZIP
# GIMZIP sample:
# <GIMZIP description="Zowe Open Source Project">
# <FILEDEF type="SMPPTFIN" archid="AZWE001.SMPMCS"
#          name="BLD.ZOWE.AZWE001.SMPMCS"/>
# <FILEDEF type="SMPRELF"  archid="AZWE001.F1"
#          name="BLD.ZOWE.AZWE001.F1"/>
# </GIMZIP>
#
# GIMUNZIP sample:
# <GIMUNZIP>
# <ARCHDEF archid="AZWE001.SMPMCS"
#          newname="@PREFIX@.ZOWE.AZWE001.SMPMCS"/>
# <ARCHDEF archid="AZWE001.F1"
#          newname="@PREFIX@.ZOWE.AZWE001.F1"/>
# </GIMUNZIP>
#
# documentation in "SMP/E for z/OS Reference (SA23-2276)"
# ---------------------------------------------------------------------
function _gimzipMeta
{
test "$debug" && echo && echo "> _gimzipMeta $@"

# get SMPMCS
mcs="${mcsHlq}.SMPMCS"
$here/$existScript $mcs
# returns 0 for exist, 2 for not exist, 8 for error
if test $rc -eq 2
then
  echo "** ERROR $me no data sets match '$mcs'"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
elif test $rc -gt 2
then
  # error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# get RELFILEs
mask="${mcsHlq}.F*"
# show everything in debug mode
test "$debug" && $here/$csiScript -d "$mask"
# get data set list (no debug mode to avoid debug messages)
datasets=$($here/$csiScript "$mask")
# returns 0 for match, 1 for no match, 8 for error
rc=$?
if test $rc -eq 1
then
  echo "** ERROR $me no data sets match '$mask'"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
elif test $rc -gt 1
then
  echo "$datasets"                       # variable holds error message
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# verify that all DSNs end in .F<number>
if test "$(echo "$datasets" | grep -v \.F[[:digit:]]*$)"
then
  echo "** ERROR $me non-RELFILE data set in RELFILE list"
  echo "$datasets" | grep -v \.F[[:digit:]]*$
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# GIMZIP SYSIN header
_cmd --repl $scratch/$sysinGimzip \
  echo "<GIMZIP description=\"$product\">"
_cmd --save $scratch/$sysinGimzip \
  echo "<FILEDEF type=\"SMPPTFIN\" archid=\"${FMID}.SMPMCS\""
_cmd --save $scratch/$sysinGimzip \
  echo "         name=\"$mcs\"/>"

# GIMUNZIP SYSIN header
_cmd --repl $scratch/$sysinGimunzip \
  echo "<GIMUNZIP>"
_cmd --save $scratch/$sysinGimunzip \
  echo "<ARCHDEF archid=\"${FMID}.SMPMCS\""
_cmd --save $scratch/$sysinGimunzip \
  echo "         newname=\"@PREFIX@.${RFDSNPFX}.${FMID}.SMPMCS\"/>"

# add RELFILEs to SYSIN
for dsn in $datasets
do
  test "$debug"&&  echo dsn=$dsn

  # ${dsn##*.} -> keep from last . (exclusive) = low level qualifier
  #GIMZIP
  _cmd --save $scratch/$sysinGimzip \
    echo "<FILEDEF type=\"SMPRELF\"  archid=\"${FMID}.${dsn##*.}\""
  _cmd --save $scratch/$sysinGimzip \
    echo "         name=\"$dsn\"/>"

  #GIMUNZIP
  _cmd --save $scratch/$sysinGimunzip \
  echo "<ARCHDEF archid=\"${FMID}.${dsn##*.}\""
  _cmd --save $scratch/$sysinGimunzip \
  echo "         newname=\"@PREFIX@.${RFDSNPFX}.${FMID}.${dsn##*.}\"/>"
done    # for f

# GIMZIP SYSIN footer
_cmd --save $scratch/$sysinGimzip echo "</GIMZIP>"

# GIMUNZIP SYSIN footer
_cmd --save $scratch/$sysinGimunzip echo "</GIMUNZIP>"

sed 's/^/. /' $scratch/$sysinGimzip           # show prefixed with '. '
test "$debug" && sed 's/^/. /' $scratch/$sysinGimunzip

test "$debug" && echo "< _gimzipMeta"
}    # _gimzipMeta

# ---------------------------------------------------------------------
# --- determine required space for extract
# sets $size
# $1: GIMZIP pax file
# ---------------------------------------------------------------------
function _size
{
test "$debug" && echo && echo "> _size $@"

# show everything in debug mode
test "$debug" && $here/$sizeScript -d "$1"
# get size (no debug mode to avoid debug messages)
primary=$($here/$sizeScript "$1")
# returns 0 for OK, 8 for error
rc=$?
if test $rc -ne 0
then
  echo $primary                          # variable holds error message
  echo "** ERROR $me unable to estimate extract size"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
echo "   $primary tracks required for unpax zFS"
  
# save value so it can be used during program directory creation
_cmd --repl $log/$extractSize echo $primary

# calculate secondary allocation size for extract zFS
if test $primary -ge 10
then 
  let secondary=$primary/10       # size of extent is 1/10th of primary
else
  secondary=1
fi    #
size="$primary $secondary"
test "$debug" && echo size=$size

test "$debug" && echo "< _size"
}    # _size

# ---------------------------------------------------------------------
# --- create readme file
# ---------------------------------------------------------------------
function _readme
{
test "$debug" && echo && echo "> _readme $@"

echo "-- creating FMID readme"

# create bulk of customized readme (in EBCDIC)
SED="s/#product/$product/g"
SED="$SED;s/#size/$size/g"
SED="$SED;s/#readme/${FMID}.readme.txt/g"
SED="$SED;s/#pax/$(basename $paxFile)/g"
_sed $here/$readme $log/$readme

# add GIMUNZIP SYSIN data
_cmd --save $log/$readme cat $scratch/$sysinGimunzip

# add footer, no _cmd to avoid expanding '*'
echo '//*' >> $log/$readme

# save readme in ASCII for easy transfer with pax file
readmeASCII=$(dirname $paxFile)/${FMID}.readme.txt
_cmd --repl $readmeASCII \
  iconv -t ISO8859-1 -f IBM-1047 $log/$readme
echo "   $readmeASCII"

test "$debug" && echo "< _readme"
}    # _readme

# ---------------------------------------------------------------------
# --- create pax file
# sets $paxFile
# $1: GIMZIP output directory, also used as base for pax name
# ---------------------------------------------------------------------
function _pax
{
test "$debug" && echo && echo "> _pax $@"

echo "-- creating FMID pax"

paxFile="$gimzip/${FMID}.pax.Z"
_cmd cd $1
# pax
#  -w                  write
#  -f ${paxfile}       output file
#  -x pax              save using pax interchange format
#  -z                  compress
#  ${paxask}          input filter
paxOpt="-w -f $paxFile -x pax -z ./*"
_cmd pax $paxOpt
_cmd cd - >/dev/null

echo "   $paxFile"
test "$debug" && echo "< _pax"
}    # _pax

# ---------------------------------------------------------------------
# --- allocate data set
# $1: data set name
# $2: record format; {FB | U | VB}
# $3: logical record length, use ** for RECFM(U)
# $4: data set organisation; {PO | PS}
# $5: space in tracks; primary[,secondary]
# ---------------------------------------------------------------------
function _alloc
{
test "$debug" && echo && echo "> _alloc $@"

# remove previous run
test "$debug" && echo
test "$debug" && echo "\"$here/$existScript $1\""
$here/$existScript "$1"
# returns 0 for exist, 2 for not exist, 8 for error
rc=$?
if test $rc -eq 0
then
  _cmd2 --null tsocmd "DELETE '$1'"
elif test $rc -gt 2
then
  # error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# create target data set
test "$debug" && echo
if test -z "$VOLSER"
then
  test "$debug" && echo "$here/$allocScript -h $1 $2 $3 $4 $5"
  $here/$allocScript -h "$1" "$2" "$3" "$4" "$5"
else
  test "$debug" && echo "$here/$allocScript -h -V $VOLSER $1 $2 $3 $4 $5"
  $here/$allocScript -h -V "$VOLSER" "$1" "$2" "$3" "$4" "$5"
fi    #
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
rc=$?
if test $rc -gt 0
then
  if test $rc -eq 1
  then
    echo "** ERROR $me data set $1 exists with wrong DCB"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  else
    # error details already reported
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
fi    # rc > 0

test "$debug" && echo "< _alloc"
}    # _alloc

# ---------------------------------------------------------------------
# --- customize a file using sed, optionally creating a new output file
#     assumes $SED is defined by caller and holds sed command string
# $1: if -x then make result executable, parm is removed when present
# $1: input file
# $2: (optional) output file, default is $1
# ---------------------------------------------------------------------
function _sed
{
unset ExEc
if test "$1" = "-x"
then                                     # make exectuable after update
  shift
  ExEc=1
fi    #

TmP=${TMPDIR:-/tmp}/$(basename $1)
_cmd --repl $TmP sed "$SED" $1                  # sed '...' $1 > $TmP
_cmd mv $TmP ${2:-$1}                           # give $TmP actual name
test -n "$ExEc" && _cmd chmod a+x ${2:-$1}      # make executable
}    # _sed

# ---------------------------------------------------------------------
# --- create symbolic link
# $1: old path
# $2: new path (symbolic link to old path)
# ---------------------------------------------------------------------
function _ln
{
test "$debug" && echo && echo "> _ln $@"

test -e $2 && _cmd rm -f $2
_cmd ln -s $1 $2

test "$debug" && echo "< _ln"
}    # _ln

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
shift $(($OPTIND-1))

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

echo "-- input:  $mcsHlq"
echo "-- output: $gimzip"

SMPJHOME=$JAVA_HOME                                         # Java home
test "$debug" && echo "SMPJHOME=$JAVA_HOME"
SMPCPATH=$SMP_HOME/classes                         # SMP/E Java classes
test "$debug" && echo "SMPCPATH=$SMP_HOME/classes"

# TODO validate $SMPJHOME
# TODO validate $SMPCPATH

base=$gimzip/$FMID        # pax, readme & work dir all start with $FMID

# clean up output of previous run
# note: GIMZIP creates data owned by UID 0
test -x "$scratch" && _cmd rm -rf $scratch  # remove temporary work dir
_cmd mkdir -p $scratch                      # create temporary work dir
_cmd mkdir -p $gimzip                               # create output dir
_cmd touch $base                           # make sure something exists
_super rm -rf $base*            # remove pax, readme, & GIMZIP work dir
_cmd mkdir -p $base                            # create GIMZIP work dir

# stage SMPMCS, RELFILEs, and GIMZIP metadata
_gimzip $base

# create pax file
_pax $base

# determine size of zFS needed to extract pax file
_size $paxFile

# create readme file
_readme

# cleanup
_super rm -rf $base                            # remove GIMZIP work dir
_cmd rm -rf $scratch                        # remove temporary work dir
# show everything in debug mode            # remove temporary data sets
test "$debug" && $here/$csiScript -d "${gimzipHlq}.*"
# get data set list (no debug mode to avoid debug messages)
datasets=$($here/$csiScript "${gimzipHlq}.*")
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

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0                                                           # EXIT
