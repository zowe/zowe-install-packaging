#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2021, 2021
#######################################################################

#% Use JCL in PTF install instructions to create install JCL.
#%
#% -?       show this help message
#% -d       enable debug messages
#% -i file  PTF install instructions
#% -j dir   directory with JCL skeletons, also used for generated JCL
#%
#% -i and -j are required

# more definitions in main()
jobUCLI=Z0PTFUCL.jcl           # name for UCLIN job
jobALOC=Z1ALLOC.jcl            # name for ALLOCATE job
jobACPT=Z2ACCEPT.jcl           # name for ACCEPT job
jobRCVE=Z3RECEIV.jcl           # name for RECEIVE job
jobAPLY=Z4APPLY.jcl            # name for APPLY job
jobREST=Z6REST.jcl             # name for RESTORE job
jobRJCT=Z7REJECT.jcl           # name for REJECT job
jobDLTE=Z8DEALOC.jcl           # name for DELETE job
jobCard=jobcard.jcl            # file holding generic job card
work=work                      # temp directory for work files
here=$(cd $(dirname $0);pwd)   # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- customize a file using sed, optionally creating a new output file
#     assumes $SED is defined by caller and holds sed command string
# $1: if -x then make result executable, parm is removed when present
# $1: input file
# $2: (optional) output file, default is $1
# ---------------------------------------------------------------------
#function _sed
_sed()
{
unset ExEc
if test "$1" = "-x"
then                                     # make exectuable after update
  shift
  ExEc=1
fi    #

TmP=${TMPDIR:-/tmp}/$(basename $1).$$
_cmd --repl $TmP sed "$SED" $1                  # sed '...' $1 > $TmP
#test "$debug" && echo
#test "$debug" && echo "sed $SED 2>&1 $1 > $TmP"
#sed "$SED" $1 2>&1 > $TmP                       # sed '...' $1 > $TmP
_cmd mv $TmP ${2:-$1}                           # give $TmP actual name
test -n "$ExEc" && _cmd chmod a+x ${2:-$1}      # make executable
}    # _sed

# ---------------------------------------------------------------------
# --- convert ASCII file to EBCDIC
# $1: if -d then delete $2 before iconv, parm is removed when present
# $1: ASCII source file
# $2: EBCDIC target file
# output:
# - $2 is created if $1 exists
# ---------------------------------------------------------------------
#function _iconv
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
#function _cmd
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
#function _displayUsage
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
#function main { }     # dummy function to simplify program flow parsing
main() { echo }       # dummy function to simplify program flow parsing

# misc setup
TMPDIR=${TMPDIR:-/tmp}
_EDC_ADD_ERRNO2=1                               # show details on error
unset ENV             # just in case, as it can cause unexpected output
_cmd umask 0022                                  # similar to chmod 755

echo; echo "-- $me - start $(date)"
echo "-- startup arguments: $@"

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# clear input variables
unset input jclDir
# do NOT unset debug

# get startup arguments
while getopts i:j:?d opt
do case "$opt" in
  d)   debug="-d";;
  i)   input="$OPTARG";;
  j)   jclDir="$OPTARG";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $(($OPTIND-1))

if test ! -f "$input"
then
  echo "** ERROR $me -i '$input' not found"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test ! -r "$input"
then
  echo "** ERROR $me -i '$input' not readable"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test ! -d "$jclDir"
then
  echo "** ERROR $me -j '$jclDir' not found"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test ! -w "$jclDir"
then
  echo "** ERROR $me -j '$jclDir' not writeable"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# expand variables
jclDir="$(cd $jclDir 2>&1;pwd)"            # make this an absolute path
jobCard=$jclDir/$jobCard
work=$jclDir/$work

# show input/output details
echo "-- input:  $input"
echo "-- output: $jclDir"

# remove workarea of previous run
test -d $work && _cmd rm -rf $work       # always delete work directory

# get ready to roll
_cmd mkdir -p $work

## convert $input to EBCDIC
#_iconv $input $work/htm
#input=$work/htm
#test "$debug" && echo "input=$input"

# pull FMID from $input
fmid=$(sed -n 's/.*DO_NOT_CHANGE_used_by_automation_FMID=//p' $input)

# ensure csplit output goes in $work
_cmd cd $work

# split $input at <!--jcl..--> markers, with .. being any 2 chars
# - csplit creates xx## files, each holding block up to next marker (exclusive)
# - "$(($(grep -c ^<!--jcl..-->$ $input)-1))" counts number of markers
#   and when wrapped in {}, it repeats the /^<!--jcl..-->$/ filter x times
_cmd csplit -s $input "/^<!--jcl..-->$/" \
  {$(($(grep -c "^<!--jcl..-->$" $input)-1))}

# return to base
_cmd --null cd -

# remove marker & HTML lines from all csplit blocks
# <!--jcl..-->
#   <PRE>
# ...
#   </PRE>
SED='1,2d;$d'
# also remove HTML tags inside JCL
SED="$SED;s~<STRONG>~~g;s~</STRONG>~~g"
test "$debug" && echo "for f in \$(ls $work/xx*)"
for f in $(ls $work/xx*)
do
  _sed $f
done    # for f

# create ALLOCATE JCL -   -   -   -   -   -   -   -   -   -   -   -   -

jobName=${jobALOC%%.*}                # keep up to first . (exclusive)}
job=$jclDir/$jobALOC
jcl=$work/xx01

# //*
# //* Change #hlq to the high level qualifier used to upload the dataset.
# //* (optional) Uncomment and change #volser to specify a volume.
# //*
# //         SET HLQ=#hlq
# //*
# //ALLOC    EXEC PGM=IEFBR14
# //UO01969  DD DSN=&HLQ..ZOWE.AZWE001.UO01969,
# //            DISP=(NEW,CATLG,DELETE),
# //            DSORG=PS,
# //            RECFM=FB,
# //            LRECL=80,
# //            UNIT=SYSALLDA,
# //*            VOL=SER=#volser,
# //*            BLKSIZE=6160,
# //            SPACE=(TRK,(6627,15))
# //*

_cmd --repl $job sed "s~^//##job ~//$jobName ~" $jobCard
# uncomment volser definition
_cmd --save $job sed '/VOL=SER/s~*~~' $jcl

# create ACCEPT JCL   -   -   -   -   -   -   -   -   -   -   -   -   -

jobName=${jobACPT%%.*}                # keep up to first . (exclusive)}
job=$jclDir/$jobACPT
jcl=$work/xx03

# //*
# //* Change #globalcsi to the data set name of your global CSI.
# //* Change #dzone to your CSI distribution zone name.
# //*
# //ACCEPT   EXEC PGM=GIMSMP,REGION=0M
# //SMPCSI   DD DISP=OLD,DSN=#globalcsi
# //SMPCNTL  DD *
#    SET BOUNDARY(#dzone) .
#    ACCEPT SELECT(
#       AZWE001
#       UO01939 UO01940 UO01942 UO01943 UO01945 UO01946 UO01948 UO01949
#       UO01951 UO01952 UO01953 UO01954 UO01955 UO01956 UO01958 UO01959
#       UO01965 UO01966
#    ) REDO COMPRESS(ALL) BYPASS(HOLDSYS,HOLDERROR).
# //*

_cmd --repl $job sed "s~^//##job ~//$jobName ~" $jobCard
# add up to "ACCEPT SELECT(" (inclusive)
_cmd --save $job sed -n '1,/SELECT(/p' $jcl
# add FMID
_cmd --save $job echo "      $fmid"
# add from ") REDO" (inclusive)
_cmd --save $job sed -n '/) REDO/,$p' $jcl

# create RECEIVE JCL  -   -   -   -   -   -   -   -   -   -   -   -   -

jobName=${jobRCVE%%.*}                # keep up to first . (exclusive)}
job=$jclDir/$jobRCVE
jcl=$work/xx05

# //*
# //* Change #hlq to the high level qualifier used to upload the dataset.
# //* Change #globalcsi to the data set name of your global CSI.
# //*
# //         SET HLQ=#hlq
# //         SET CSI=#globalcsi
# //*
# //RECEIVE  EXEC PGM=GIMSMP,REGION=0M
# //SMPCSI   DD DISP=OLD,DSN=&CSI
# //SMPPTFIN DD DISP=SHR,DSN=&HLQ..ZOWE.AZWE001.UO01969
# //SMPCNTL  DD *
#    SET BOUNDARY(GLOBAL) .
#    RECEIVE SELECT(
#      UO01969
#
#    ) SYSMODS LIST .
# //*

_cmd --repl $job sed "s~^//##job ~//$jobName ~" $jobCard
_cmd --save $job cat $jcl

# create APPLY JCL    -   -   -   -   -   -   -   -   -   -   -   -   -

jobName=${jobAPLY%%.*}                # keep up to first . (exclusive)}
job=$jclDir/$jobAPLY
jcl=$work/xx07

# //*
# //* Change #globalcsi to the data set name of your global CSI.
# //* Change #tzone to your CSI target zone name.
# //* Once the APPLY CHECK is successful, remove the CHECK operand
# //*  and run the APPLY step again to do the actual APPLY.
# //*
# //         SET CSI=#globalcsi
# //*
# //APPLY    EXEC PGM=GIMSMP,REGION=0M
# //SMPCSI   DD DISP=OLD,DSN=&CSI
# //SMPCNTL  DD *
#    SET BOUNDARY(#tzone) .
#    APPLY SELECT(
#      UO01969
#
#    )
#    CHECK
#    BYPASS(HOLDSYS,HOLDERROR)
#    REDO COMPRESS(ALL) .
# //*

_cmd --repl $job sed "s~^//##job ~//$jobName ~" $jobCard
_cmd --save $job cat $jcl
## comment out CHECK
#_cmd --save $job sed 's~  CHECK$~  /*CHECK*/~' $jcl

# create DELETE JCL   -   -   -   -   -   -   -   -   -   -   -   -   -

jobName=${jobDLTE%%.*}                # keep up to first . (exclusive)}
job=$jclDir/$jobDLTE
jcl=$work/xx09

# //*
# //* Change #hlq to the high level qualifier used to upload the dataset.
# //*
# //         SET HLQ=#hlq
# //*
# //DEALLOC  EXEC PGM=IEFBR14
# //UO01969  DD DSN=&HLQ..ZOWE.AZWE001.UO01969,
# //            DISP=(OLD,DELETE,DELETE)
# //*

_cmd --repl $job sed "s~^//##job ~//$jobName ~" $jobCard
_cmd --save $job cat $jcl

# create RESTORE JCL  -   -   -   -   -   -   -   -   -   -   -   -   -

jobName=${jobRJCT%%.*}                # keep up to first . (exclusive)}
job=$jclDir/$jobRJCT
jcl=$work/xx11

# //*
# //* The RESTORE process will replace the affected elements in the
# //* target libraries with the version from the distribution
# //* libraries. This implies that you cannot RESTORE a SYSMOD once it
# //* has been accepted. This also implies that you must RESTORE all
# //* SYSMODS that have been applied since the last accepted SYSMOD.
# //*
# //* Change #globalcsi to the data set name of your global CSI.
# //* Change #tzone to your CSI target zone name.
# //*
# //         SET CSI=#globalcsi
# //*
# //RESTORE  EXEC PGM=GIMSMP,REGION=0M
# //SMPCSI   DD DISP=OLD,DSN=&CSI
# //SMPCNTL  DD *
#    SET BOUNDARY(#tzone) .
#    LIST SYSMODS .
#    RESTORE SELECT(
#      UO01969
#
#    ) .
# //*

_cmd --repl $job sed "s~^//##job ~//$jobName ~" $jobCard
_cmd --save $job cat $jcl

# create REJECT JCL   -   -   -   -   -   -   -   -   -   -   -   -   -

jobName=${jobREST%%.*}                # keep up to first . (exclusive)}
job=$jclDir/$jobREST
jcl=$work/xx13

# //*
# //* REJECT automatically acts on co-requisite SYSMODs as well,
# //* so only one SYSMOD is specified.
# //*
# //* Change #globalcsi to the data set name of your global CSI.
# //*
# //         SET CSI=#globalcsi
# //*
# //REJECT   EXEC PGM=GIMSMP,REGION=0M
# //SMPCSI   DD DISP=OLD,DSN=&CSI
# //SMPCNTL  DD *
#    SET BOUNDARY(GLOBAL) .
#    LIST SYSMODS .
#    REJECT SELECT(
#      UO01969
#    ) BYPASS(APPLYCHECK) .
# //*

_cmd --repl $job sed "s~^//##job ~//$jobName ~" $jobCard
_cmd --save $job cat $jcl

# create UCLIN JCL    -   -   -   -   -   -   -   -   -   -   -   -   -

jobName=${jobUCLI%%.*}                # keep up to first . (exclusive)}
job=$jclDir/$jobUCLI
jcl=$work/xx15

# //*
# //* Change #globalcsi to the data set name of your global CSI.
# //* Change #tzone to your CSI target zone name.
# //* Change #dzone to your CSI distribution zone name.
# //*
# //UCLIN    EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)
# //SMPLOG   DD SYSOUT=*
# //SMPCSI   DD DISP=OLD,DSN=#globalcsi
# //SMPCNTL  DD *
#    SET BOUNDARY(GLOBAL) .
#    UCLIN .
#    REP DDDEF(SYSUT1)  CYL SPACE(450,100)
#        UNIT(SYSALLDA) VOLUME(#volser)
#        .
#    ENDUCL .
#    
#    SET BOUNDARY(#tzone) .
#    UCLIN .
#    REP DDDEF(SYSUT1)  CYL SPACE(450,100)
#        UNIT(SYSALLDA) VOLUME(#volser)
#        .
#    REP DDDEF(SMPWRK6) CYL SPACE(450,100) DIR(50)
#        UNIT(SYSALLDA) VOLUME(#volser)
#        .
#    ENDUCL .
#    
#    SET BOUNDARY(#dzone) .
#    UCLIN .
#    REP DDDEF(SMPWRK6) CYL SPACE(450,100) DIR(50)
#        UNIT(SYSALLDA) VOLUME(#volser)
#        .
#    ENDUCL .
# //*

_cmd --repl $job sed "s~^//##job ~//$jobName ~" $jobCard
_cmd --save $job cat $jcl

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# remove workarea of this run
_cmd rm -rf $work

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0                                                           # EXIT
