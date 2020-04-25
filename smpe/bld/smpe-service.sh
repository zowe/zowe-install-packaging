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
#% -?            show this help message
#% -b branch     GitHub branch used for this build
#% -B build      GitHub build number for this branch
#% -c smpe.yaml  use the specified config file
#% -d            enable debug messages
#% -P            fail build if APAR/USERMOD is created instead of PTF
#% -p version    product version
#%
#% -c is required

# Assumes that SMPMCS and RELFILEs are in sync with each other

# require $JAVA_HOME                Java home directory
# require $mcsHlq.*                 RELFILEs & SMPMCS
# creates $ship/$zip                zip holding SYSMODs & readme (ASCII)
# creates $ship/$tarPromote         tar holding promote info (ASCII)
# creates $log/$jclGimdts           gimdts JCL
# creates $log/$logGimdts           gimdts sysprint output
# creates $log/$jclMerge            merge ++ & part JCL
# creates $log/$logMerge            merge ++ & part sysprint output
# creates $log/$sysmod1.readme.htm  readme (EBCDIC)
# creates $log/$curClose            customized sample closing info
# creates $log/$thisApar            list of APAR(s) in this PTF
# creates $log/$thisHold            hold info new to this PTF

# relationship between this sysmod and other sysmods
# ++PTF      REQ ptfNames
#            SUP aparNames
#            SUP <curApar>
#            SUP <prevApar>
#            SUP <prevPtf>
# ++APAR     /   ptfNames
#            REQ aparNames
#            SUP <curApar>
#            PRE <prevApar>
#            PRE <prevPtf>
# ++USERMOD  /   ptfNames
#            REQ aparNames (holding list of related USERMODs)
#            SUP <curApar>
#            PRE <prevApar>
#            PRE <prevPtf>

# more definitions in main()
gimdtsTools=""                 # tools used by jobs
gimdtsTools="$gimdtsTools PTF@.jcl"
gimdtsTools="$gimdtsTools PTF@FB80.jcl"
gimdtsTools="$gimdtsTools PTF@LMOD.jcl"
gimdtsTools="$gimdtsTools PTF@MVS.jcl"
gimdtsTools="$gimdtsTools PTFMERGE.jcl"
gimdtsTools="$gimdtsTools PTFTRKS.jcl"
gimdtsTools="$gimdtsTools RXDDALOC.rex"
gimdtsTools="$gimdtsTools RXLINES.rex"
gimdtsTools="$gimdtsTools RXUNLOAD.rex"
gimdtsTools="$gimdtsTools RXTRACKS.rex"
maxExecMerge=120               # limit EXEC statements per merge job
jclMerge=gimmerge.jcl          # merge invocation JCL
logMerge=gimmerge.sysprint.log # merge SYSPRINT log
tracks=gimmerge.tracks.txt     # PTF track count
maxExecGimdts=60               # limit EXEC statements per GIMDTS job
jclGimdts=gimdts.jcl           # GIMDTS invocation JCL
logGimdts=gimdts.sysprint.log  # GIMDTS SYSPRINT log
lines=gimdts.lines.txt         # GIMDTS line count
readme=ptf.readme.htm          # PTF install instructions
mcs=SMPMCS.txt                 # SMPMCS (install metadata)
service=./service              # directory with service-specific files
# >> next block of files is in the $service directory
ptfBucket=ptf-bucket.txt       # list of available PTFs
curApar=current-apar.txt       # list of additional APARs to supersede
curClose=current-close.txt     # closing info for this PTF
curHold='current-hold-*.txt'   # hold info for this PTF
fixHold='fixed-hold-*.txt'     # hold info added to all PTFs
# <<
thisApar=current-apar.txt      # formatted list of APARs to supersede
thisClose=current-close.txt    # formatted closing info for this PTF
thisHold=current-hold.txt      # formatted hold info for this sysmod
thisHold2=current-hold2.txt    # formatted commented hold info for PTF
thisPtf=current-ptf.txt        # formatted list of current PTFs
prevApar=promoted-apar.txt     # list of all previous APARs
prevClose=promoted-close.txt   # closing info of previous PTFs
prevHold=promoted-hold.txt     # hold info of previous PTFs
prevPtf=promoted-ptf.txt       # list of all previous PTFs
tarPromote=smpe-promote.tar    # tar-file holding $prev* files
splitScript=ptf-split.rex      # script to distribute parts across PTFs
submitScript=wait-for-job.sh   # submit script
dcbScript=check-dataset-dcb.sh # script to test dcb of data set
existScript=check-dataset-exist.sh  # script to test if data set exists
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
# --- return PRE/SUP/REQ formatted list of sysmods for $header & $readme
# $1: PRE | SUP | REQ
# $2: file with list of sysmods
# output:
# - $2 is updated
# - $ptf/$readme.$1 is created
# ---------------------------------------------------------------------
function _formatPreSupReq
{
test "$debug" && echo && echo "> _formatPreSupReq $@"

test -s $ptf/err && _cmd rm -f $ptf/err

# reformat list of sysmods, result saved in temp file
# input: lines with x number of blank delimited sysmod names per line
# sample output:
#       AH02861,AH02907,AH02908,AH06007,AH06132,AH06136,AH06139,AH09610
#       AI91621,AI91622,AI95415,AI95536,AI95543,AI98069,AI99136,AI99137
#       UI52748,UI52749,UI52750,UI54690,UI54691,UI54692,UI56525,UI56526
#       UI61814,UI61815,UI63579,UI63580,UI63581)
# 1. tr    replace all blanks with new-lines    -> 0 or 1 word per line
# 2. sed   strip null lines                          -> 1 word per line
# 3. sort  sort sysmod names
# 4. awk   merge blocks of 8 lines in single line,
#          words are separated by comma,
#          last line ends with comma if not 8th word
# 5. sed   strip possible trailing comma
# 6. sed   add ) to end of last line
# 7. sed   prefix all lines with 6 blanks
test "$debug" && echo "cat $2 | ..."
cat $2                2>> $ptf/err \
  | tr ' ' '\n'       2>> $ptf/err \
  | sed '/^$/d'       2>> $ptf/err \
  | sort              2>> $ptf/err \
  | awk 'NR%8 {printf("%s,",$0); next} {print $0}' 2>> $ptf/err \
  | sed 's/,$//'      2>> $ptf/err \
  | sed '$ s/$/)/'    2>> $ptf/err \
  | sed 's/^/      /' 2>> $ptf/err \
  1> $ptf/tmp         2>> $ptf/err

if test -s $ptf/err
then
  echo "** ERROR $me problem formatting $1 $2"
  cat $ptf/err
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# remove trailing ), save list for readme
# sample output:
#       AH02861,AH02907,AH02908,AH06007,AH06132,AH06136,AH06139,AH09610
#       AH09614,AH13239,AH13307,AH13308,AH19771,AH19939,AH19940,AI91486
#       UI52748,UI52749,UI52750,UI54690,UI54691,UI54692,UI56525,UI56526
#       UI61814,UI61815,UI63579,UI63580,UI63581
_cmd --repl $ptf/$readme.$1 sed "s/)//" $ptf/tmp

# add REQ/PRE/SUP to first line, replace original input
# sample output:
#   SUP(AH02861,AH02907,AH02908,AH06007,AH06132,AH06136,AH06139,AH09610
#       AH09614,AH13239,AH13307,AH13308,AH19771,AH19939,AH19940,AI91486
#       UI52748,UI52749,UI52750,UI54690,UI54691,UI54692,UI56525,UI56526
#       UI61814,UI61815,UI63579,UI63580,UI63581)
_cmd --repl $2 sed "1 s/      /  $1(/" $ptf/tmp

_cmd rm -f $ptf/tmp
test "$debug" && echo "< _formatPreSupReq"
}    # _formatPreSupReq

# ---------------------------------------------------------------------
# --- create PRE (prerequisite) and SUP (supersede) statements
# $1: header file name
# output:
# - $1  is updated if needed
# ---------------------------------------------------------------------
function _sup
{
test "$debug" && echo && echo "> _sup $@"

sup=$ptf/sup
test -f $sup && _cmd rm -f $sup
_cmd touch $sup                             # ensure output file exists

if test "$sysmodType" = "++PTF"
then                                      # PTF SUPs everything, no PRE
  # group everything that must go in SUP()
  # APAR number starts with I, matching APAR-fix number starts with A
  test -f $ptf/$thisApar && \
    _cmd --save $sup sed 's/^./A/' $ptf/$thisApar
  test -f $service/$prevApar && \
    _cmd --save $sup sed 's/^./A/' $service/$prevApar
  test -f $service/$prevPtf && \
    _cmd --save $sup cat $service/$prevPtf

  test -f $sup && _formatPreSupReq SUP $sup
else      # APAR & USERMOD PRE previous sysmods, and SUP interim builds
  if test -f $ptf/$thisApar                                      #  SUP
  then
    # APAR number starts with I, matching APAR-fix number starts with A
    _cmd --save $sup sed 's/^./A/' $ptf/$thisApar
    _formatPreSupReq SUP $sup
  fi    # SUP

  if test -f $service/$prevApar -o -f $service/$prevPtf           # PRE
  then
    test -f $ptf/pre && _cmd rm -f $ptf/pre

    # APAR number starts with I, matching APAR-fix number starts with A
    test -f $service/$prevApar && \
      _cmd --save $ptf/pre sed 's/^./A/' $service/$prevApar
    test -f $service/$prevPtf && \
      _cmd --save $ptf/pre cat $service/$prevPtf

    _formatPreSupReq PRE $ptf/pre
    _cmd --save $sup cat $ptf/pre               # append result to $sup
    _cmd rm -f $ptf/pre
  fi    # PRE
fi    # APAR/USERMOD

test "$debug" && sed 's/^/. /' $sup           # show prefixed with '. '
_cmd --save $1 cat $sup

# no longer needed
_cmd rm -f $ptf/sup

test "$debug" && echo "< _sup"
}    # _sup

# ---------------------------------------------------------------------
# --- add PTF-specific comments to header
# $1: header file name
# output:
# - $1  is updated
#
#   PROBLEM DESCRIPTION(S):
#     AO00204 -
#       PROBLEM SUMMARY:
#       <current-close.txt>
#
#     AO00205 -
#       PROBLEM SUMMARY:
#       <current-close.txt>
#
#     <promoted-close.txt>
#
#   COMPONENT:
#     5698-ZWE00-AZWE001
#
#   APARS FIXED:
#     IO00204
#     IO00205
#     <current-apar.txt>
#     <promoted-apar.txt>
#
# ---------------------------------------------------------------------
function _ptfComments
{
test "$debug" && echo && echo "> _ptfComments $@"

#   PROBLEM DESCRIPTION(S):
_cmd --save $1 echo "  PROBLEM DESCRIPTION(S):"

#     IO00204 -
#       PROBLEM SUMMARY:
#       <current-close.txt>
#
#     ...
_cmd --save $1 cat $ptf/$thisClose

#   COMPONENT:
#     5698-ZWE00-AZWE001
#
_cmd --save $1 echo "  COMPONENT:"
_cmd --save $1 echo "    ${compID}-$FMID"
_cmd --save $1 echo ""

#   APARS FIXED:
#     IO00204
#     IO00205
#     <current-apar.txt>
#     <promoted-apar.txt>
#
_cmd --save $1 echo "  APARS FIXED:"
_cmd --save $1 sed 's/^/    /' $ptf/$thisApar         # indent 4 spaces
test -f $service/$prevApar && \
  _cmd --save $1 sed 's/^/    /' $service/$prevApar   # indent 4 spaces
_cmd --save $1 echo ""

test "$debug" && echo "< _ptfComments"
}    # _ptfComments

# ---------------------------------------------------------------------
# --- create header for sysmod (PTF/APAR/USERMOD)
# $1: header file name
# $2: sysmod name, use "#SySmOdNaMe" for sysmod 2 and up
#     (sysmod 2 and up does not get hold info)
# output:
# - $1  file with sysmod header (#req used as placeholder for REQ)
#
# ++PTF(UO64071) /* 5698-ZWE00-AZWE001 */ REWORK(2019271).
# ++VER(Z038) FMID(AZWE001)
#   REQ(UO64072)
#   SUP(AO00204,AO00205,UO61806)
#  /*
#   PROBLEM DESCRIPTION(S):
#     AO00204 -
#       PROBLEM SUMMARY:
#       <current-close.txt>
#
#     AO00205 -
#       PROBLEM SUMMARY:
#       <current-close.txt>
#
#     <promoted-close.txt>
#
#   COMPONENT:
#     5698-ZWE00-AZWE001
#
#   APARS FIXED:
#     IO00204
#     IO00205
#     <current-apar.txt>
#     <promoted-apar.txt>
#
#   SPECIAL CONDITIONS:
#     ACTION:
#       <current-hold-ACTION.txt>
#       <fixed-hold-ACTION.txt>
#       <promoted-hold-ACTION.txt>
#
#     ...:
#       <...>
#
#     COPYRIGHT:
#       5698-ZWE00 COPYRIGHT Contributors to the Zowe Project. 2019
#
#   COMMENTS:
#     COMMUNITY VERSION:
#       1.8.0
#
#     GITHUB BRANCH:
#       master (build 15)
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
# ...
# ---------------------------------------------------------------------
function _header
{
test "$debug" && echo "> _header $@"
echo "-- creating header $sysmodType($2)"

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# ++PTF(UO64071) /* 5698-ZWE00-AZWE001 */ REWORK(2019271).
_cmd --repl $1 \
  echo "$sysmodType($2) /* $compID-$FMID */ REWORK($julian7)."

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# ++VER(Z038) FMID(AZWE001)
# get value from SMPMCS
environment=$(sed -n '/^++VER/ s/++VER(\(.*\)).*/\1/p' $here/$mcs)
_cmd --save $1 echo "++VER($environment) FMID($FMID)"

#   REQ(UO64072)
# use placeholder for "REQ(...)", added later
_cmd --save $1 echo "#req"

#   SUP(AO00204,AO00205,UO61806)
#   PRE(UO61808)
_sup $1

#  /*
_cmd --save $1 echo ' /*'

# extended comment block for PTF only
#   PROBLEM DESCRIPTION(S):
#     AO00204 -
#       PROBLEM SUMMARY:
#       <current-close.txt>
#
#     AO00205 -
#       PROBLEM SUMMARY:
#       <current-close.txt>
#
#     <promoted-close.txt>
#
#   COMPONENT:
#     5698-ZWE00-AZWE001
#
#   APARS FIXED:
#     IO00204
#     IO00205
#     <current-apar.txt>
#     <promoted-apar.txt>
#
test "$sysmodType" = "++PTF" &&  _ptfComments $1

#   SPECIAL CONDITIONS:
_cmd --save $1 echo "  SPECIAL CONDITIONS:"

# hold as comment for first PTF only
#     ACTION:
#       <current-hold-ACTION.txt>
#       <fixed-hold-ACTION.txt>
#       <promoted-hold-ACTION.txt>
#
#     ...:
#       <...>
#
test "$sysmodType" = "++PTF" \
  -a $2 != "#SySmOdNaMe" \
  -a -f $ptf/$thisHold2 && \
  _cmd --save $1 cat $ptf/$thisHold2

# note: COPYRIGHT is part of SPECIAL CONDITIONS, so extra indentation
#     COPYRIGHT:
#       5698-ZWE00 COPYRIGHT Contributors to the Zowe Project. 2019
#
_cmd --save $1 echo "    COPYRIGHT:"
_cmd --save $1 echo "      ${compID} COPYRIGHT $copyright"
_cmd --save $1 echo ""

#   COMMENTS:
#     COMMUNITY BUILD:
#       1.8.0
#
#     GITHUB BRANCH:
#       master (build 15)
_cmd --save $1 echo "  COMMENTS:"
_cmd --save $1 echo "    COMMUNITY VERSION:"
line2="$VERSION"
test "$debug" && echo "while test -n \"\$line2\""
while test -n "$line2"               # write version in 63-char chuncks
do
  line1=$(echo $line2 | cut -c 1-63)
  line2=$(echo $line2 | sed 's/^.\{1,63\}//')
  test "$debug" && echo "line1='$line1'"
  test "$debug" && echo "line2='$line2'"
  _cmd --save $1 echo "      $line1"
done    # while $line2
_cmd --save $1 echo ""
_cmd --save $1 echo "    GITHUB BRANCH:"
line2="$BRANCH (build $BUILD)"
test "$debug" && echo "while test -n \"\$line2\""
while test -n "$line2"           # write branch name in 63-char chuncks
do
  line1=$(echo $line2 | cut -c 1-63)
  line2=$(echo $line2 | sed 's/^.\{1,63\}//')
  test "$debug" && echo "line1='$line1'"
  test "$debug" && echo "line2='$line2'"
  _cmd --save $1 echo "      $line1"
done    # while $line2

#  */.
_cmd --save $1 echo ' */.'

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# hold as ++HOLD for first sysmod
if test $2 != "#SySmOdNaMe"
then
  test -f $ptf/$thisHold && _cmd --save $1 cat $ptf/$thisHold

  # ++PTF SUPs promoted PTFs, and thus includes their hold info
  test "$sysmodType" = "++PTF" -a -f $service/$prevHold && \
    _cmd --save $1 cat $service/$prevHold
fi    # add ++HOLD

test "$debug" && sed 's/^/. /' $1             # show prefixed with '. '
test "$debug" && echo "< _header"
}    # _header

# ---------------------------------------------------------------------
# --- create headers for first and overflow sysmods
# output:
# - $ptf/header1  file holding header for first sysmod (with hold)
# - $ptf/header2  file holding header for overflow sysmods (no hold)
# ---------------------------------------------------------------------
function _headers
{
test "$debug" && echo && echo "> _headers $@"

_header $ptf/header1 $sysmod1
_header $ptf/header2 '#SySmOdNaMe'

test "$debug" && echo "< _headers"
}    # _headers

# ---------------------------------------------------------------------
# --- merge PTF header, MCS metadata, and parts
# IBM: max PTF size is 5,000,000 * 80 bytes (including SMP/E metadata)
#      5mio FB80 lines requires 7,164 tracks
# output:
# - $ptf/$ptfHLQ.$sysmodName  PTF(s)
# - $ptf/$tracks              track count per PTF
# - $log/$jclMerge            archival of jcl(s)
# - $log/$logMerge            archival of job output(s)
# note: writing to data set avoids JCL issues with long path names
# ---------------------------------------------------------------------
function _merge
{
test "$debug" && echo && echo "> _merge $@"
echo "-- creating $(echo $sysmodType | sed 's/^..//')s"

# remove archived merge data, if any
test -f $log/$jclMerge && _cmd rm -f $log/$jclMerge
test -f $log/$logMerge && _cmd rm -f $log/$logMerge

# pre-allocate output data set (has to be done here in case we
# need to submit multiple jobs)
_alloc "$SYSPRINT" "FBA" "121" "PS" "5,5"

# pre-allocate track count data set (has to be done here in case we
# need to submit multiple jobs)
_alloc "$TRACKS" "FB" "80" "PS" "5,5"

# build list of sysmods to create
if test "$sysmodType" = "++PTF"
then
  sysmods="$ptfNames"
elif test "$sysmodType" = "++APAR"
then
  sysmods="$aparNames"
else  # ++USERMOD
  # build list of USERMOD names (TMPxxxx)
  # USERMOD numbering starts at number of $sysmod1
  prefix=$(echo $sysmod1 | sed 's/....$//')              # keep first 3
  number=$(echo $sysmod1 | sed 's/^...//')                # keep last 4
  sysmods=$sysmod1
  cnt=1
  while test $cnt -ne $distroCnt
  do
    let cnt=$cnt+1
    let number=$number+1
    # make number at least 4 chars long & keep last 4 chars
    number=$(echo 000$number | sed 's/.*\(....\)$/\1/')
    sysmods="$sysmods $prefix$number"
  done    # while $cnt
fi    # create $sysmods
test "$debug" && echo "sysmods=$sysmods"

# loop through $distro to merge header & parts into the actual sysmod
cnt=1
test "$debug" && echo "while test \$cnt -le \$distroCnt"
while test $cnt -le $distroCnt
do
  test "$debug" && echo "cnt=$cnt"

  # get sysmod name from sysmods list (assumes $sysmods is formatted)
  # 1. tr   replace all blanks with new-lines        -> 1 word per line
  # 2. sed  only keep line $cnt
  sysmodName=$(echo $sysmods | tr ' ' '\n' | sed -n "${cnt}p")
  test "$debug" && echo "sysmodName=$sysmodName"

  # create REQ() for this sysmod
  # TODO rework using _formatPreSupReq() when +8 REQ sysmods
  # 1. strip this sysmod name
  # 2. strip leading blanks
  # 3. strip trailing blanks
  # 4. reduce multiple blanks to 1 blank
  # 5. replace all blanks with commas
  req=$(echo $sysmods \
        | sed "s/$sysmodName//;s/^ *//;s/ *$//;s/[ ]\{2,\}/ /;s/ /,/")
  if test -z "$req"
  then  # only 1 sysmod, no REQ
    req='  /* REQ() */'
  else
    req="  REQ($req)"
  fi    #
  test "$debug" && echo "req=$req"

  # get (line with) list of parts for this sysmod
  parts=$(echo "$distro" | sed -n "${cnt}p")
  test "$debug" && echo "parts=$parts"

  # report
  echo "   $sysmodType($sysmodName)"

  # allocate data set used to merge header and parts
  # IBM: max PTF size is 5,000,000 * 80 bytes (including SMP/E metadata)
  #      5mio FB80 lines requires 7,164 tracks
  _alloc --multi "$SYSMOD" "FB" "80" "PS" "7164,5"

  # select correct header
  if test $cnt -eq 1
  then  # header first sysmod (has hold data)
    header=$ptf/header1
  else  # header overflow sysmod (no hold data)
    header=$ptf/header2
  fi    #

  # populate staging data set with header
  # TODO rework when +8 REQ sysmods
  SED=""
  SED="$SED;s/#SySmOdNaMe/$sysmodName/"
  SED="$SED;s/^#req$/$req/"
  _sedMVS -s $header "$SYSMOD"

  # prime merge JCL
  _primeJCL $ptf $jclMerge "$cnt $sysmodType $sysmodName"

  # loop through parts
  test "$debug" && echo "for part in \$parts"
  for part in $parts
  do
    # did we reach max EXEC statements for current job ?
    if test $cntExec -eq maxExecMerge
    then                   # yes, submit current job and create new job
      # archive job (if multiple jobs then string together)
      _cmd --save $log/$jclMerge cat $ptf/$jclMerge

      # run the job
      _submit $ptf/$jclMerge $log/$logMerge

      # create new job (append to existing $SYSPRINT & $SYSMOD)
      _primeJCL $cnt $jclMerge $cnt
    fi    # new job

    # pad part name with blanks to 8 characters
    part=$(echo "$part      " | sed 's/^\(........\).*/\1/')

    # update JCL
    _cmd --save $ptf/$jclMerge \
      echo "//$part EXEC PROC=PTFMERGE,PART=$part"

    # increase EXEC counter
    let cntExec=$cntExec+1
  done    # for part

  # add track count step to JCL
  _cmd --save $ptf/$jclMerge \
    echo "//TRACKS   EXEC PROC=PTFTRKS,PTF=${ptfHLQ}.$sysmodName"

  # archive job (if multiple jobs then string together)
  _cmd --save $log/$jclMerge cat $ptf/$jclMerge

  # run the job
  _submit $ptf/$jclMerge $log/$logMerge

  # show job output in debug mode
  if test "$debug"
  then
    echo "-- $logMerge $(cat $log/$logMerge | wc -l) line(s)"
    sed 's/^/. /' $log/$logMerge              # show prefixed with '. '
    echo "   merge $cnt successful"
  fi    #

  # save sysmod created by merge job(s)
  test "$debug" && echo
  test "$debug" && echo "\"$here/$existScript $SYSMOD\""
  $here/$existScript "$SYSMOD"
  # returns 0 for exist, 2 for not exist, 8 for error
  existRC=$?
  if test $existRC -eq 0
  then
    _cmd cp -B "//'$SYSMOD'" "$ptf/${ptfHLQ}.$sysmodName"
  else
    echo "** ERROR $me merge job $cnt did not create //'$SYSMOD'"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    # no $SYSMOD

  test "$debug" && echo "end while \$cnt -- $cnt/$distroCnt"

  # process next sysmod
  let cnt=$cnt+1
done    # while $cnt

# no longer needed
_cmd rm -f $ptf/$jclMerge

# save track count created by merge job(s)
test "$debug" && echo
test "$debug" && echo "\"$here/$existScript $TRACKS\""
$here/$existScript "$TRACKS"
# returns 0 for exist, 2 for not exist, 8 for error
existRC=$?
if test $existRC -eq 0
then
  _cmd cp "//'$TRACKS'" $ptf/$tracks
else
  echo "** ERROR $me merge job did not create //'$TRACKS'"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    # no $TRACKS

test "$debug" && echo "< _merge"
}    # _merge

# ---------------------------------------------------------------------
# --- create install instructions
# output:
# - $log/$html  install instructions (EBCDIC)
# - $name1      name of first SYSMOD, used as base for $html name
# ---------------------------------------------------------------------
function _readme
{
test "$debug" && echo && echo "> _readme $@"
echo "-- creating readme"

# get file name of first PTF (awk prints second word of first line)
# expected content:
# 4806 ZOWE.AZWE001.TMP0001
# 3800 ZOWE.AZWE001.TMP0002
name1=$(awk 'BEGIN{f=1} f{f=0;print $2}' $ptf/$tracks)
sysmod1=${name1##*.}                # keep from last period (exclusive)
test $debug && echo "name1=$name1"
test $debug && echo "sysmod1=$sysmod1"

# define name of readme HTML
html=${name1}.${readme#*.}       # ${#*.} keep from first . (exclusive)
test $debug && echo "html=$html"

# define name of $tracks without first sysmod (holds coreqs)
tracksCoreq=coreq.$tracks
test $debug && echo "tracksCoreq=$tracksCoreq"

# create $tracks without first sysmod (holds coreqs)
SED='1d'
_sed $ptf/$tracks $ptf/$tracksCoreq

# create work copy of install instructions
_cmd cp $here/$readme $ptf/$readme

# ensure csplit output goes in $ptf
_cmd cd $ptf

# split instructions at <!--cut..--> markers, with .. being any 2 chars
# - csplit creates xx## files, each holding block up to next marker (exclusive)
# - "$(($(grep -c ^<!--cut..-->$ $ptf/$readme)-1))" counts number of markers
#   and when wrapped in {}, it repeats the /^<!--cut..-->$/ filter x times
_cmd csplit -s $ptf/$readme "/^<!--cut..-->$/" \
  {$(($(grep -c "^<!--cut..-->$" $ptf/$readme)-1))}

# return to base
_cmd --null cd -

# give first csplit block the final name (rest will append)
_cmd mv $ptf/xx00 $log/$html

# remove marker line from all remaining csplit blocks
SED='1d'
test "$debug" && echo "for f in \$(ls $ptf/xx*)"
for f in $(ls $ptf/xx*)
do
  _sed $f
done    # for f

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# create dummy PRE/SUP data files if they do not exist
# if there is data then file is created by _formatPreSupReq()
test -f $ptf/$readme.PRE || _cmd --save $ptf/$readme.PRE echo none
test -f $ptf/$readme.SUP || _cmd --save $ptf/$readme.SUP echo none

# add list of PRE sysmods (replace , with blank so broswer can reformat)
_cmd --save $log/$html sed "s/,/ /g" $ptf/$readme.PRE

# append next csplit block (xx01 holds PRE placeholder)
_cmd --save $log/$html cat $ptf/xx02

# add list of SUP sysmods (replace , with blank so broswer can reformat)
_cmd --save $log/$html sed "s/,/ /g" $ptf/$readme.SUP

# append next csplit block (xx03 holds SUP placeholder)
_cmd --save $log/$html cat $ptf/xx04

# add an allocation statement for each sysmod
test "$debug" && echo "while read -r trk name"
while read -r trk name
do
  sysmod=${name##*.}                # keep from last period (exclusive)
  test $debug && echo "(alloc) trk=$trk, name=$name, sysmod=$sysmod"

  # pad sysmod name with blanks to 8 characters
  sysmod8=$(echo "$sysmod      " | sed 's/^\(........\).*/\1/')

  # append customized data
  # expected xx01 content:
  # //#ptf8 DD DSN=&HLQ..#name,
  # //            DISP=(NEW,CATLG,DELETE),
  # //            DSORG=PS,
  # //            RECFM=FB,
  # //            LRECL=80,
  # //            UNIT=SYSALLDA,
  # //*            VOL=SER=<STRONG>#volser</STRONG>,
  # //*            BLKSIZE=6160,
  # //            SPACE=(TRK,(#pri,15))
  SED=""
  SED="$SED;s/#ptf8/$sysmod8/"
  SED="$SED;s/#name/$name/"
  SED="$SED;s/#pri/$trk/"
  _cmd --save $log/$html sed "$SED" $ptf/xx05
done < $ptf/$tracks    # while read

# append next csplit block
_cmd --save $log/$html cat $ptf/xx06

# add a FTP statement for each sysmod
test "$debug" && echo "while read -r trk name"
while read -r trk name
do
  bytes=$(ls -l $ptf/$name | awk '{print $5}')
  test $debug && echo "(ftp) name=$name, bytes=$bytes"

  # append customized data
  # expected xx07 content:
  # </I>ftp&gt; <STRONG>put d:\#name</STRONG>
  # <I>200 Port request OK.
  # 125 Storing data set #hlq.#name
  # 250 Transfer completed successfully
  # #bytes bytes sent in 0.28 seconds
  SED=""
  SED="$SED;s/#name/$name/"
  SED="$SED;s/#bytes/$bytes/"
  _cmd --save $log/$html sed "$SED" $ptf/xx07
done < $ptf/$tracks    # while read

# append next csplit block
_cmd --save $log/$html cat $ptf/xx08

# start off with no hold data
test -f $ptf/tmp && _cmd rm -f $ptf/tmp
# stage current hold data
test -f $ptf/$thisHold && _cmd --save $ptf/tmp cat $ptf/$thisHold
# ++PTF SUPs promoted PTFs, and thus includes their hold info
test "$sysmodType" = "++PTF" -a -f $service/$prevHold && \
  _cmd --save $ptf/tmp cat $service/$prevHold

# append hold data
if test -f $ptf/tmp
then
  _cmd --save $log/$html cat $ptf/tmp
else
  _cmd --save $log/$html echo none
fi    #

# append next csplit block (xx09 holds HOLD placeholder)
_cmd --save $log/$html cat $ptf/xx10

# add a requisite data set names to RECEIVE SMPPTFIN (sysmod 2 and up)
test "$debug" && echo "while read -r trk name"
while read -r trk name
do
  test $debug && echo "(SMPPTFIN) name=$name"

  # append customized data
  _cmd --save $log/$html echo "//         DD DISP=SHR,DSN=&HLQ..$name"
done < $ptf/$tracksCoreq    # while read         # all but first sysmod

# append next csplit block (xx11 holds DSN placeholder)
_cmd --save $log/$html cat $ptf/xx12

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# get requisite sysmod names (sysmod 2 and up)
unset coreq
test "$debug" && echo "while read -r trk name"
while read -r trk name
do
  sysmod=${name##*.}                # keep from last period (exclusive)
  coreq="$coreq $sysmod"
done < $ptf/$tracksCoreq    # while read         # all but first sysmod
coreq=$(echo $coreq)                              # strip leading blank
test $debug && echo "coreq=$coreq"

# customize common variables
SED=""
SED="$SED;s/#type/$sysmodType/"
SED="$SED;s/#name1/$name1/"
SED="$SED;s/#ptf1/$sysmod1/"
SED="$SED;s/#fmid/$FMID/"
SED="$SED;s/#rework/$julian7 ($yyyymmdd)/"
SED="$SED;s/#req/$coreq/"
_sed $log/$html

# no longer needed
_cmd rm -f $ptf/$tracksCoreq  $ptf/$readme $ptf/xx*  $ptf/tmp
_cmd rm -f $ptf/$readme.PRE   $ptf/$readme.SUP

test "$debug" && echo "< _readme"
}    # _readme

# ---------------------------------------------------------------------
# --- zip up sysmods & instructions
# output:
# - $ship/$zip  zip with sysmods & readme
# ---------------------------------------------------------------------
function _zip
{
test "$debug" && echo && echo "> _zip $@"
echo "-- creating zip"

# ensure output directory exists
_cmd mkdir -p $ship

# define name of zip            # example: $name1=ZOWE.AZWE0001.TMP0001
zip=${name1#*.}.zip                     # keep from first . (exclusive)
test $debug && echo "zip=$zip"

# get names of all sysmods
unset names
test "$debug" && echo "while read -r trk name"
while read -r trk name
do
  names="$names $name"
done < $ptf/$tracks    # while read
names=$(echo $names)                              # strip leading blank
test $debug && echo "names=$names"

# convert html encoding from EBCDIC to ASCII
_cmd --repl $ptf/$html iconv -t ISO8859-1 -f IBM-1047 $log/$html

# go to correct path to avoid path inclusion in zip
_cmd cd $ptf

# create zip file (c: create, M: no manifest, f: file name)
_cmd $JAVA_HOME/bin/jar -cMf $ship/$zip $names $html

# no longer needed
_cmd rm -f $tracks $names $html

# return to base
_cmd --null cd -

test "$debug" && echo "< _zip"
}    # _zip

# ---------------------------------------------------------------------
# --- determine how to distribute parts across sysmods
# output:
# - $distroCnt  number of sysmods
# - $distro      each line holds parts for 1 sysmod
# ---------------------------------------------------------------------
function _split
{
test "$debug" && echo && echo "> _split $@"

# get size of header for main sysmod
headerLinesFirst=$(cat $ptf/header1 | wc -l)
# get size of header for overflow sysmod(s)
headerLinesOther=$(cat $ptf/header2 | wc -l)

if test "$sysmodType" = "++PTF"
then
  cnt=$(echo $ptfNames | wc -w)
elif test "$sysmodType" = "++APAR"
then
  cnt=$(echo $aparNames | wc -w)
else
  cnt=""
fi    #

# sort part line counts
# -r reverse (descending)
# -n first key is numeric
# -o output file (can be input file)
_cmd sort -r -n -o $ptf/$lines $ptf/$lines
# sample output:
# 1494165 ZWEPAX05
#  933752 ZWEPAX06
#       6 ZWESIPRG

# show $lines in debug mode
if test "$debug"
then
  echo "-- $lines $(cat $ptf/$lines | wc -l) line(s)"
  sed 's/^/. /' $ptf/$lines                   # show prefixed with '. '
fi    #

# determine how to distribute the parts across the sysmods
args="$ptf/$lines $headerLinesFirst $headerLinesOther $cnt"
# show everything in debug mode
test "$debug" && $here/$splitScript -d "$args"
# get data (no debug mode to avoid debug messages)
distro="$($here/$splitScript $args)"
# returns 0 for success, 8/12 for error
rc=$?
# sample output:
# ZWEPAX05 ZWESIPRG
# ZWEPAX06

if test $rc -ne 0
then
  echo "$distro"                        # variable holds error messages
  echo "** ERROR $me script RC $rc for part distribution"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# how many sysmods do we need to create?
distroCnt=$(echo "$distro" | wc -l)

# we don't have an expected count for USERMOD, use actual count
test "$sysmodType" = "++USERMOD" && cnt=$distroCnt

# does this match the number of sysmods we have for this set?
if test $cnt -ne $distroCnt
then
  echo "** ERROR $me $distroCnt sysmods needed, $cnt available"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# no longer needed
_cmd rm -f $ptf/$lines

test "$debug" && echo "< _split"
}    # _split

# ---------------------------------------------------------------------
# --- create & submit GIMDTS job
# Assumes that all parts have metadata, and all metadata has a part
# output:
# - &HLQ..&MLQ.*     parts in FB80 format
# - $ptf/$lines      FB80 line count per part
# - $log/$jclGimdts  archival of jcl(s)
# - $log/$logGimdts  archival of job output(s)
# note: writing to data set avoids JCL issues with long path names
# ---------------------------------------------------------------------
function _gimdts
{
test "$debug" && echo "> _gimdts $@"
echo "-- processing RELFILEs"

# pre-allocate output data set (has to be done here in case we need
# to submit multiple GIMDTS jobs)
# note: GIMDTS assumes FBA121 for output and does not write \n, so
# writing directly to a USS file results in all output on a single line
_alloc "$SYSPRINT" "FBA" "121" "PS" "5,5"

# pre-allocate line count data set (has to be done here in case we need
# to submit multiple jobs)
_alloc "$LINES" "FB" "80" "PS" "5,5"

# remove archived GIMDTS data, if any
test -f $log/$jclGimdts && _cmd rm -f $log/$jclGimdts
test -f $log/$logGimdts && _cmd rm -f $log/$logGimdts

# prime JCL
_primeJCL $ptf $jclGimdts

# get RELFILE data set list
# show everything in debug mode
test "$debug" && $here/$csiScript -d "${mcsHlq}.F*"
# get RELFILE data set list (no debug mode to avoid debug messages)
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

# loop through RELFILE data sets
test "$debug" && echo "for dsn in \$datasets"
for dsn in $datasets
do
  # update JCL
  _cmd --save $ptf/$jclGimdts echo "//         SET REL=$dsn"

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
  allParts="$allParts $members"   # keep track of everything we process
# echo "   $dsn ($(echo $members | wc -l | sed s'/ //g' members))"
  test "$debug" && echo "for member in \$members"
  for member in $members
  do
    # did we reach max EXEC statements for current job ?
    if test $cntExec -eq maxExecGimdts
    then                   # yes, submit current job and create new job
      # archive job (if multiple jobs then string together)
      _cmd --save $log/$jclGimdts cat $ptf/$jclGimdts

      # run the job
      _submit $ptf/$jclGimdts $log/$logGimdts

      # create new job (append to existing $SYSPRINT & $LINES)
      _primeJCL $ptf $jclGimdts
      _cmd --save $ptf/$jclGimdts echo "//         SET REL=$dsn"
    fi    # new job

    # pad member name with blanks to 8 characters
    member=$(echo "$member      " | sed 's/^\(........\).*/\1/')

    # update JCL
    _cmd --save $ptf/$jclGimdts \
      echo "//$member EXEC PROC=$proc,MBR=$member"

    # increase EXEC counter
    let cntExec=$cntExec+1
  done    # for member
done    # for dsn

# archive job (if multiple jobs then string together)
_cmd --save $log/$jclGimdts cat $ptf/$jclGimdts

# run the job
_submit $ptf/$jclGimdts $log/$logGimdts

# show job output in debug mode
if test "$debug"
then
  echo "-- $logGimdts $(cat $log/$logGimdts | wc -l) line(s)"
  sed 's/^/. /' $log/$logGimdts                # show prefixed with '. '
  echo "   GIMDTS successful"
fi    #

# no longer needed
_cmd rm -f $ptf/$jclGimdts

# save line count of GIMDTS job(s)
test "$debug" && echo
test "$debug" && echo "\"$here/$existScript $LINES\""
$here/$existScript "$LINES"
# returns 0 for exist, 2 for not exist, 8 for error
existRC=$?
if test $existRC -eq 0
then
  _cmd cp "//'$LINES'" $ptf/$lines
else
  echo "** ERROR $me GIMDTS job did not create //'$LINES'"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    # no $LINES

test "$debug" && echo "< _gimdts"
}    # _gimdts

# ---------------------------------------------------------------------
# --- submit job & wait on completion, with error handling
# $1: job to submit
# $2: file where to save job output
# output:
# - $2  job output
# ---------------------------------------------------------------------
function _submit
{
test "$debug" && echo "> _submit $@"

test "$debug" && echo
test "$debug" && echo "\"$here/$submitScript $debug -c $1\""
$here/$submitScript $debug -c $1
# returns
# 0: job completed with RC 0
# 1: job completed with an acceptable RC
# 2: job completed, but not with an acceptable RC
# 3: job ended abnormally (abend, JCL error, ...)
# 4: job did not complete in time
# 5: job purged before we could process
# 8: error
submitRC=$?

# save output of GIMDTS job(s)
test "$debug" && echo
test "$debug" && echo "\"$here/$existScript $SYSPRINT\""
$here/$existScript "$SYSPRINT"
# returns 0 for exist, 2 for not exist, 8 for error
existRC=$?
if test $existRC -eq 0
then
  _cmd cp "//'$SYSPRINT'" $2
else
  # remove output from previous run, if any
  test -f $2 && _cmd rm -f $2
  # create dummy to ensure next step can rely on the file existing
  _cmd touch $2
  echo "** INFO created dummy $2"
fi    # no $SYSPRINT

# test for job failure
if test $submitRC -ne 0
then
  test "$debug" && echo "job failure"
  echo "-- $(basename $2) $(cat $2 | wc -l) line(s)"
  sed 's/^/. /' $2                            # show prefixed with '. '

  # error details already reported
  echo "** ERROR $me script RC $submitRC for submit of job $1"
  case "$submitRC" in
    0)   echo "   job completed with RC 0";;
    1)   echo "   job completed with an acceptable RC";;
    2)   echo "   job completed, but not with an acceptable RC";;
    3)   echo "   job ended abnormally (abend, JCL error, ...)";;
    4)   echo "   job did not complete in time";;
    5)   echo "   job purged before we could process";;
    8)   echo "   $submitScript script error";;
    [?]) echo "   undocumented error code";;
  esac    # $submitRC
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

test "$debug" && echo "< _submit"
}    # _submit

# ---------------------------------------------------------------------
# --- allocate data set (removes pre-existing one)
# $1: if --multi then allow multi volume, parm is removed when present
# $1: data set name
# $2: record format; {FB | U | VB}
# $3: logical record length, use ** for RECFM(U)
# $4: data set organisation; {PO | PS}
# $5: space in tracks; primary[,secondary]
# output:
# - $1  allocated data set
# ---------------------------------------------------------------------
function _alloc
{
test "$debug" && echo && echo "> _alloc $@"

unset allocParms

# multi-volume permitted ? (dsOrg PS required)     MUST be tested first
if test "$1" = "--multi"
then
  shift
  test -n "$gimdtsUCount" && allocParms="$allocParms -C $gimdtsUCount"
fi    #

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

# hide allocation command when not in debug mode
test "$debug" || allocParms="$allocParms -h"

# allocate on specific volser(s)
test -n "$gimdtsVolser" && allocParms="$allocParms -V $gimdtsVolser"

# create target data set
test "$debug" && echo
test "$debug" && echo \
  "\"$here/$allocScript $allocParms $1 $2 $3 $4 $5\""
$here/$allocScript $allocParms "$1" "$2" "$3" "$4" "$5"

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
# --- get list of members in data set, skip aliases
# $1: data set
# output:
# - $members  list of part names
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
# output:
# - $?  boolean indicating DCB match
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
# $1: target directory
# $2: jcl file name
# $3: value for #comment, cannot have semicolon (:) in it
# output:
# - $1/$2     jcl
# - $cntExec  initialzed EXEC statement counter
# ---------------------------------------------------------------------
function _primeJCL
{
test "$debug" && echo "> _primeJCL $@"

# prime GIMDTS job JCL
SED=""
SED="$SED;s:#job1:$gimdtsJob1:"
SED="$SED;s:#hlq:$gimdtsHlq:"
SED="$SED;s:#mlq:$MLQ:"
SED="$SED;s:#sysprint:$SYSPRINT:"
SED="$SED;s:#lines:$LINES:"
SED="$SED;s:#sysmod:$SYSMOD:"
SED="$SED;s:#tracks:$TRACKS:"
SED="$SED;s:#comment:$3:"
_cmd --repl $1/$2 sed "$SED" $here/$2

# current number of JCL EXEC statements
cntExec=0

test "$debug" && echo "< _primeJCL"
}    # _primeJCL

# ---------------------------------------------------------------------
# --- stage GIMDTS JCL procedures & support REXX
# output:
# - $gimdtsHlq(*)  procs & rexx
# ---------------------------------------------------------------------
function _tools
{
test "$debug" && echo "> _tools $@"
echo "-- staging GIMDTS support tools"

# place tools in $gimdtsHlq (no extra LLQ)
_alloc "$gimdtsHlq" "FB" "80" "PO" "5,5"

# store customized tools
if test -z "$gimdtsVolser"
then
  SED="s:#volser://*           VOL=SER=#volser,:"
else
  SED="s:#volser://            VOL=SER=$gimdtsVolser,:"
fi    #
SED="$SED;s:#trks:$gimdtsTrks:"
SED="$SED;s:#mlq:$MLQ:"

test "$debug" && echo "for file in \$gimdtsTools"
for file in $gimdtsTools
do
  _sedMVS $here/$file $gimdtsHlq
done    # for file

test "$debug" && echo "< _tools"
}    # _tools

# ---------------------------------------------------------------------
# --- stage SMP/E metadata for parts to package
# output:
# - &HLQ..&MLQ.*  data set per part primed with MCS data
# ---------------------------------------------------------------------
function _metaData
{
test "$debug" && echo "> _metaData $@"
echo "-- staging SMP/E metadata"
mcs=SMPMCS.txt

# create work copy of MCS
_cmd cp "//'${mcsHlq}.SMPMCS'" $ptf/$mcs

# ensure csplit output goes in $ptf
_cmd cd $ptf

# split MCS in individual '++' control statements
# - csplit creates xx## files, each holding exactly 1 control statement
# - "$(($(grep -c ^++ $ptf/$mcs)-1))" counts number of ++ in column 1
#   and when wrapped in {}, it repeats the /^++/ filter x times
_cmd csplit -s $ptf/$mcs /^++/ {$(($(grep -c ^++ $ptf/$mcs)-1))}

# return to base
_cmd --null cd -

# create directory to stage processed '++' control statements
_cmd mkdir -p $ptf/meta

# process individual '++' control statements
unset found
test "$debug" && echo "for file in \$(ls $ptf/xx*)"
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
    _cmd --repl $ptf/meta/$name sed 's/ RELFILE([[:digit:]]*)//' $file
  fi    #
done    # for file

# remove work MCS & csplit output
_cmd rm -f $ptf/$mcs $ptf/xx*

if test -z "$found"
then
  echo "** ERROR $me parsing ${mcsHlq}.SMPMCS did not yield MCS data"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# move all MCS data to datasets to simplify debugging GIMDTS job issues
allParts=$(ls $ptf/meta)
test "$debug" && echo "for file in \$allParts*)"
for file in $allParts
do
  # TODO KEEP DSN IN SYNC WITH $here/PTF@.jcl
  _alloc --multi "${gimdtsHlq}.${MLQ}.$file" "FB" "80" "PS" "$gimdtsTrks"
  _cmd mv $ptf/meta/$file "//'${gimdtsHlq}.${MLQ}.$file'"
done    # for file

# no longer needed
_cmd rmdir $ptf/meta

echo "   $(echo $allParts | wc -w | sed 's/ *//g') MCS defintions"
test "$debug" && echo "< _metaData"
}    # _metaData

# ---------------------------------------------------------------------
# --- clean up external input - PTF
# output:
# - $ptf/$thisPtf is created if there is data (current as list)
# ---------------------------------------------------------------------
function _prepPtf
{
test "$debug" && echo && echo "> _prepPtf $@"

if test "$sysmodType" != "++PTF"
then
  test "$debug" && echo "no action, not ++PTF"
else
  # save list of PTFs
  # input: line with x number of blank delimited sysmod names
  # sample output:
  # UO64071
  # UO64072
  # 1. tr    replace all blanks with new-lines  -> 0 or 1 word per line
  # 2. sed   strip null lines                        -> 1 word per line
  # 3. sort  sort sysmod names & strip duplicates
  test "$debug" && echo "echo \$ptfNames | ..."
  echo $ptfNames     2>> $ptf/err \
    | tr ' ' '\n'    2>> $ptf/err \
    | sed '/^$/d'    2>> $ptf/err \
    | sort -u        2>> $ptf/err \
    1> $ptf/$thisPtf 2>> $ptf/err

  if test -s $ptf/err
  then
    echo "** ERROR $me problem formatting ++PTF $ptfNames"
    cat $ptf/err
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
    _cmd rm $ptf/err
  fi    #

  test "$debug" && sed 's/^/. /' $ptf/$thisPtf #show prefixed with '. '
fi    # ++PTF

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# ensure there are no duplicates in current and promoted PTF lists
if test -f $ptf/$thisPtf -a -f $service/$prevPtf
then
  # assumes both files are formatted
  duplicates="$(comm -12 $ptf/$thisPtf $service/$prevPtf 2>&1)"

  if test -n "$duplicates"
  then
    echo "** ERROR $me duplicate PTFs in $thisPtf and $prevPtf"
    echo $duplicates
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
fi    # test for duplicate PTF numbers

# ensure there are no duplicates in $ptfNames
if test -f $ptf/$thisPtf -a \
  "$(echo $ptfNames | wc -w)" -ne "$(cat $ptf/$thisPtf | wc -l)"
then
  echo "** ERROR $me duplicate PTF numbers in $service/$ptfBucket"
  echo "$(echo $ptfNames | wc -w) -ne $(cat $ptf/$thisPTf | wc -l)"
  echo $ptfNames
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

test "$debug" && echo "< _prepPtf"
}    # _prepPtf

# ---------------------------------------------------------------------
# --- clean up external input - hold info
# output:
# - $ptf/$thisHold is created if there is data (current as ++HOLD)
# - $ptf/$thisHold2 is created if there is data (all as comment)
# ---------------------------------------------------------------------
function _prepHold
{
test "$debug" && echo && echo "> _prepHold $@"

test "$debug" && echo "+ merge current & fixed HOLD info, grouped by type"

# merge current & fixed HOLD info, grouped by type
test "$debug" && \
  echo "for file in \$(ls $service/\$curHold $service/\$fixHold)"
for file in $(ls $service/$curHold $service/$fixHold 2> /dev/null)
do
  test "$debug" && echo "file=$file"

  # check for line-length errors (max 64 chars)
  if test -n "$(sed -n 's/^.\{1,64\}//p' $file | sed '/^$/d')"
  then
    echo "** ERROR $me more than 64 chars per line in $file"
    echo "'----+----1----+----2----+----3----+----4----+----5----+----6----'"
    sed "s/^/'/;s/$/'/" $file                  # show surrounded by ' '
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #

  # e.g. /bld/zowe/service/fixed-hold-ACTION.txt -> ACTION
  holdType=$(echo $file | sed 's:.*-\(.*\)\.txt$:\1:')
  test "$debug" && echo "holdType=$holdType"

  _cmd --save $ptf/${holdType}.hold cat $file
  # ensure trailing blank line
  test -n "$(tail -1 $ptf/${holdType}.hold)" &&
    _cmd --save $ptf/${holdType}.hold echo ""
done    # for file

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

test "$debug" && echo "+ format grouped hold info in ++HOLD layout"

# format grouped hold info in ++HOLD layout
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
# ...
test "$debug" && echo "for file in \$(ls $ptf/*.hold)"
for file in $(ls $ptf/*.hold 2> /dev/null)
do
  test "$debug" && echo "file=$file"

  # e.g. /bld/zowe/ptf/ACTION.hold -> ACTION
  holdType=$(echo $(basename $file) | sed 's/[.].*//')
  test "$debug" && echo "holdType=$holdType"

   _cmd --save $ptf/$thisHold echo \
 "++HOLD($sysmod1) SYSTEM FMID($FMID) REASON($holdType) DATE($julian5)"
   _cmd --save $ptf/$thisHold echo "  COMMENT("
   _cmd --save $ptf/$thisHold sed 's/^/  /' $file     # indent 2 spaces
   _cmd --save $ptf/$thisHold echo "  )."
done    # for file

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# ++PTF SUPs promoted PTFs, and includes their hold info
# -> merge promoted hold with current hold and group by type
# MUST be done AFTER creating current ++HOLD (also used by APAR/USERMOD)
if test "$sysmodType" = "++PTF" -a -f $service/$prevHold
then
  test "$debug" && echo "+ merge promoted hold with current hold and group by type"

  # ensure csplit output goes in $ptf
  _cmd cd $ptf

  # split at ++HOLD markers
  # - csplit creates xx## files, each holding block up to next marker (exclusive)
  # - "$(($(grep -c ^++HOLD $service/$prevHold)-1))" counts number of markers
  #   and when wrapped in {}, it repeats the /^++HOLD/ filter x times
  _cmd csplit -s $service/$prevHold "/^++HOLD/" \
    {$(($(grep -c "^++HOLD" $service/$prevHold)-1))}

  # return to base
  _cmd --null cd -

  # group actual data (no SMPE metadata) by type
  test "$debug" && echo "for file in \$(ls $ptf/xx*)"
  for file in $(ls $ptf/xx* 2> /dev/null)
  do
    test "$debug" && echo "file=$file"

    # e.g. ++HOLD(UO61806) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(19071)
    #      -> ACTION
    holdType=$(head -1 $file | sed 's/.*REASON(\([^)]*\).*/\1/')
    test "$debug" && echo "holdType=$holdType"

    # save content by type
    if test -n "$holdType"
    then
      # strip first 2 and last line (SMP/E metadata lines)
      # remove leading 2 blanks
      _cmd --save $ptf/${holdType}.hold sed '1,2d;$d;s/^..//' $file
    fi    #
  done    # for file

  # no longer needed
  _cmd rm -f $ptf/xx*
fi    # merge hold of previous PTFs

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

if test "$sysmodType" = "++PTF"
then
  test "$debug" && echo "+ HOLD info in comment format, grouped by type"

  # TODO chop $ptf/*.hold in individual hold statements and remove
  #      duplicates before formatting

  # PTFs list HOLD info in comments as well, format by type
  #     ACTION:
  #       <ACTION.hold>
  #
  #     ...:
  #       <...>
  #
  test "$debug" && echo "for file in \$(ls $ptf/*.hold)"
  for file in $(ls $ptf/*.hold 2> /dev/null)
  do
    test "$debug" && echo "file=$file"

    # e.g. /bld/zowe/ptf/ACTION.hold -> ACTION
    holdType=$(echo $(basename $file) | sed 's/[.].*//')
    test "$debug" && echo "holdType=$holdType"

    _cmd --save $ptf/$thisHold2 echo "    $holdType:"
    _cmd --save $ptf/$thisHold2 sed 's/^/      /' $file      # indent 6
    test "$(tail -1 $ptf/$thisHold2)" != "      " &&
      _cmd --save $ptf/$thisHold2 echo ""  # ensure trailing blank line
  done    # for file
fi    # ++PTF

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# no longer needed
_cmd rm -f $ptf/*.hold

if test "$debug"
then                                          # show prefixed with '. '
  echo "++HOLD format"
  test -f $ptf/$thisHold && sed 's/^/. /' $ptf/$thisHold
  echo "comment format"
  test -f $ptf/$thisHold2 && sed 's/^/. /' $ptf/$thisHold2
fi    #

test "$debug" && echo "< _prepHold"
}    # _prepHold

# ---------------------------------------------------------------------
# --- clean up external input - closing info
# output:
# - $ptf/$thisClose is created if there is data (all as comment)
# ---------------------------------------------------------------------
function _prepClose
{
test "$debug" && echo && echo "> _prepClose $@"

# PTF has closing information, format it
if test "$sysmodType" != "++PTF"
then
  test "$debug" && echo "no action, not ++PTF"
else
  # check for line-length errors (max 64 chars)
  if test -n "$(sed -n 's/^.\{1,64\}//p' $service/$curClose | sed '/^$/d')"
  then
    echo "** ERROR $me more than 64 chars per line in $service/$curClose"
    echo "'----+----1----+----2----+----3----+----4----+----5----+----6----'"
    sed "s/^/'/;s/$/'/" $service/$curClose     # show surrounded by ' '
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #

  #     IO00204 -
  #       PROBLEM SUMMARY:
  #       <current-close.txt>
  #
  test "$debug" && echo "for sysmod in \$(cat $ptf/$thisApar)"
  for sysmod in $(cat $ptf/$thisApar)
  do
    _cmd --save $ptf/tmp echo "    $sysmod -"
    _cmd --save $ptf/tmp echo "      PROBLEM SUMMARY:"
    # indent 6 spaces
    _cmd --save $ptf/tmp sed 's/^/      /' $service/$curClose
    test "$(tail -1 $ptf/tmp)" != "      " && \
      _cmd --save $ptf/tmp echo ""         # ensure trailing blank line
  done    # for sysmod

  # substitute placeholders that came in with <curClose>
  # TODO KEEP IN SYNC with stageShopz()
  SED=""
  SED="$SED; s/#fmid/$FMID/"
  SED="$SED; s/#version/$VERSION/"
  SED="$SED; s,#link,$ptfHttp,"              # $ptfHttp has '/' and ':'
  _sed $ptf/tmp

  # enusre subtitutions did not bring us past 64 chars (+6 offset)
  _cmd --repl $ptf/$thisClose cut -c 1-70 $ptf/tmp

  test "$debug" && sed 's/^/. /' $ptf/$thisClose #show prefixed with'. '

  # ++PTF SUPs promoted PTFs, and includes their closing info
  test -f $service/$prevClose && \
    _cmd --save $ptf/$thisClose cat $service/$prevClose

  # no longer needed
  _cmd rm -f $ptf/tmp
fi    # ++PTF

test "$debug" && echo "< _prepClose"
}    # _prepClose

# ---------------------------------------------------------------------
# --- clean up external input - APAR
# output:
# - $ptf/$thisApar is created if there is data (current as list)
# ---------------------------------------------------------------------
function _prepApar
{
test "$debug" && echo && echo "> _prepApar $@"

# create work copy
test -f $service/$curApar && _cmd cp $service/$curApar $ptf/$thisApar

# ++PTF will SUP aparNames & <thisApar>, so put them together
test "$sysmodType" = "++PTF" && \
  _cmd --save $ptf/$thisApar echo $aparNames

# create known format for <thisApar> input
if test ! -f $ptf/$thisApar
then
  test "$debug" && echo "no action, missing $ptf/$thisApar"
else
  # reformat list of sysmods, result saved in temp file
  # input: lines with x number of blank delimited sysmod names per line
  # sample output:
  # IO00204
  # IO00205
  # 1. tr    replace all blanks with new-lines  -> 0 or 1 word per line
  # 2. sed   strip null lines                        -> 1 word per line
  # 3. sort  sort sysmod names & strip duplicates
  test "$debug" && echo "cat $ptf/$thisApar | ..."
  cat $ptf/$thisApar 2>> $ptf/err \
    | tr ' ' '\n'    2>> $ptf/err \
    | sed '/^$/d'    2>> $ptf/err \
    | sort -u        2>> $ptf/err \
    1> $ptf/tmp      2>> $ptf/err

  if test -s $ptf/err
  then
    echo "** ERROR $me problem formatting ++APAR $ptf/$thisApar"
    cat $ptf/err
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
    _cmd rm $ptf/err
  fi    #

  # replace unformatted <thisApar> with formatted version
  _cmd mv $ptf/tmp $ptf/$thisApar

  test "$debug" && sed 's/^/. /' $ptf/$thisApar #show prefixed with '. '
fi    # $ptf/$thisApar exists

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# ensure there are no duplicates in current and promoted APAR lists
if test -f $ptf/$thisApar -a -f $service/$prevApar
then
  # assumes both files are formatted
  duplicates="$(comm -12 $ptf/$thisApar $service/$prevApar 2>&1)"

  if test -n "$duplicates"
  then
    echo "** ERROR $me duplicate APARs in $thisApar and $prevApar"
    echo $duplicates
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
fi    # test for duplicate APAR numbers

test "$debug" && echo "< _prepApar"
}    # _prepApar

# ---------------------------------------------------------------------
# --- clean up external input
# output:
# - $ptf/$thisApar is created if there is data (current as list)
# - $ptf/$thisClose is created if there is data (all as comment)
# - $ptf/$thisHold is created if there is data (current as ++HOLD)
# - $ptf/$thisHold2 is created if there is data (all as comment)
# - $ptf/$thisPtf is created if there is data (current as list)
# ---------------------------------------------------------------------
function _prepInput
{
test "$debug" && echo && echo "> _prepInput $@"

_prepApar
_prepClose
_prepHold
_prepPtf

test "$debug" && echo "< _prepInput"
}    # _prepInput

# ---------------------------------------------------------------------
# --- stage ASCII data to be used as historical data after promote
#     The files will hold the current and previous info so we can
#     just replace the previous historical files ($prev*) on promote.
# output:
# - $ship/$tarPromote is created when packaging a PTF
# ---------------------------------------------------------------------
function _stagePromote
{
test "$debug" && echo && echo "> _stagePromote $@"

# clear the stage
test -f $ship/$tarPromote && _cmd rm -f $ship/$tarPromote

if test "$sysmodType" != "++PTF"
then  # ++APAR/++USERMOD
  _cmd touch $ship/$tarPromote        # ensure file exists as null-file
else  # ++PTF
  # these will replace the current $prev* files on promote
  _iconv -d $ptf/$thisApar     $ship/$prevApar       # only has current
  _iconv    $service/$prevApar $ship/$prevApar           # add promoted

  _iconv -d $ptf/$thisClose $ship/$prevClose   # has current & promoted

  _iconv -d $ptf/$thisHold     $ship/$prevHold       # only has current
  _iconv    $service/$prevHold $ship/$prevHold           # add promoted

  _iconv -d $ptf/$thisPtf      $ship/$prevPtf        # only has current
  _iconv    $service/$prevPtf  $ship/$prevPtf            # add promoted

  # current PTF(s) to know how to update $ptfBucket on promote
  _iconv -d $ptf/$thisPtf      $ship/$thisPtf        # only has current

  # create tar-file for usage by external process smpe-promote.sh
  # use tar as smpe-promote.sh does not run on z/OS
  _cmd cd $ship
  files="$(ls $prevApar $prevClose $prevHold $prevPtf $thisPtf \
    2> /dev/null)"
  test "$debug" && echo "files=$files"
  if test -n "$files"
  then
    _cmd tar -cf $tarPromote $files
    _cmd rm -f $files
  fi    #
  _cmd --null cd -
fi    # ++PTF

test "$debug" && echo "< _stagePromote"
}    # _stagePromote

# ---------------------------------------------------------------------
# --- stage data to simplify redistribution of PTFs via IBM's Shopz
# output:
# - $log/$curClose  is created when packaging a PTF
# - $log/$thisApar  is created when packaging a PTF
# - $log/$thisHold  is created when packaging a PTF & there is data
# ---------------------------------------------------------------------
function _stageShopz
{
test "$debug" && echo && echo "> _stageShopz $@"

test -f $log/$curClose && _cmd rm -f $log/$curClose
test -f $log/$thisApar && _cmd rm -f $log/$thisApar
test -f $log/$thisHold && _cmd rm -f $log/$thisHold

if test "$sysmodType" != "++PTF"
then  # ++APAR/++USERMOD
  test "$debug" && echo "no action, not ++PTF"
else  # ++PTF
  # straight copy for these, no changes required
  test -f $ptf/$thisApar && _cmd cp $ptf/$thisApar $log/$thisApar
  test -f $ptf/$thisHold && _cmd cp $ptf/$thisHold $log/$thisHold

  # substitute placeholders that are in  <curClose>
  # TODO KEEP IN SYNC with prepClose()
  SED=""
  SED="$SED; s/#fmid/$FMID/"
  SED="$SED; s/#version/$VERSION/"
  SED="$SED; s,#link,$ptfHttp,"              # $ptfHttp has '/' and ':'
  _sed $service/$curClose $ptf/tmp

  # enusre subtitutions did not bring us past 64 chars
  _cmd --repl $log/$curClose cut -c 1-64 $ptf/tmp

  test "$debug" && sed 's/^/. /' $log/$curClose #show prefixed with '. '
  _cmd rm -f $ptf/tmp
fi    # ++PTF

test "$debug" && echo "< _stageShopz"
}    # _stageShopz

# ---------------------------------------------------------------------
# --- determine whether to create PTF, APAR, or USERMOD
# output:
# - sysmodType  ++PTF | ++APAR | ++USERMOD
# - sysmod1     UOxxxxx | AOxxxxx | TMPxxxx
# - aparNames   list of APAR numbers to use (as ++APAR or SUP)
# - ptfNames    list of PTF numbers to use (as ++PTF)
# ---------------------------------------------------------------------
function _type
{
test "$debug" && echo && echo "> _type $@"

unset aparNames ptfNames
if test ! -f $service/$ptfBucket
then                                        # $ptfBucket does not exist
  sysmodType="++USERMOD"
  test "$debug" && echo "$sysmodType - no $service/$ptfBucket"
else                                              # file exists
  # get first non-comment line, can be null
  line="$(sed '/^#/d' $service/$ptfBucket | head -1)"
  # output: "<ptfs> - <apars>"  or  "<apars>"
  test "$debug" && echo "line=$line"

  # get APAR names, trim leading & trailing blanks, reduce +1 blanks
  aparNames="$(echo $line \
             | sed 's/.*-//;s/^ *//;s/ *$//;s/[ ]\{2,\}/ /g' )"
  test "$debug" && echo "aparNames='$aparNames'"

  if test "$(echo $line | grep -)"
  then                            # ++PTF if there is a '-' in the data
    sysmodType="++PTF"
    test "$debug" && echo "$sysmodType - PTFs in $service/$ptfBucket"

    # get PTF names, trim leading & trailing blanks, reduce +1 blanks
    ptfNames="$(echo $line \
              | sed 's/-.*//;s/^ *//;s/ *$//;s/[ ]\{2,\}/ /g')"
    test "$debug" && echo "ptfNames='$ptfNames'"

    if test -z "$ptfNames"
    then                    # no PTF numbers found while we should have
      echo "** ERROR $me $service/$ptfBucket format error (PTF)"
      echo "line: '$line'"
      test ! "$IgNoRe_ErRoR" && exit 8                           # EXIT
    fi    #

    if test -z "$aparNames"
    then                   # no APAR numbers found while we should have
      echo "** ERROR $me $service/$ptfBucket format error (APAR)"
      echo "line: '$line'"
      test ! "$IgNoRe_ErRoR" && exit 8                           # EXIT
    fi    #
  # not a ++PTF
  elif test -n "$aparNames"
  then                                # ++APAR if aparNames is non-null
    sysmodType="++APAR"
    test "$debug" && echo "$sysmodType - APARs in $service/$ptfBucket"
  else                             # ++USERMOD if no data in $ptfBucket
    sysmodType="++USERMOD"
    test "$debug" && echo "$sysmodType - $service/$ptfBucket empty"
  fi    #
fi    # $ptfBucket exists

# PTF required ?
if test -n "$reqPTF" -a "$sysmodType" != "++PTF"
then
  echo "** ERROR $me ++PTF build required, but $sysmodType selected"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# determine name of first sysmod
if test "$sysmodType" = "++PTF"
then
  sysmod1=${ptfNames%% *}          # keep up to first blank (exclusive)
elif test "$sysmodType" = "++APAR"
then
  # keep up to first blank (exclusive)
  # APAR number starts with I, matching APAR-fix number starts with A
  sysmod1=$(echo ${aparNames%% *} | sed 's/^./A/')
else  # ++USERMOD
  # TODO update here to increase USERMOD number on consecutive builds
  sysmod1=TMP0001
fi    #

echo "-- packaging $sysmodType($sysmod1) & family"
test "$debug" && echo "< _type"
}    # _type

# ---------------------------------------------------------------------
# --- delete data sets
# $1: HLQ of data sets to delete
# ---------------------------------------------------------------------
function _deleteDatasets
{
test "$debug" && echo && echo "> _deleteDatasets $@"

# show everything in debug mode
test "$debug" && $here/$csiScript -d "$1.**"
# get data set list (no debug mode to avoid debug messages)
datasets=$($here/$csiScript "$1.**")
# returns 0 for match, 1 for no match, 8 for error
if test $? -gt 1
then
  echo "$datasets"                       # variable holds error message
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
# delete data sets
test "$debug" && echo "for dsn in \$datasets"
for dsn in $datasets
do
  _cmd2 --null tsocmd "DELETE '$dsn'"
done    # for dsn

test "$debug" && echo "< _deleteDatasets"
}    # _deleteDatasets

# ---------------------------------------------------------------------
# --- convert EBCDIC file to ASCII
# $1: if -d then delete $2 before iconv, parm is removed when present
# $1: EBCDIC source file
# $2: ASCII target file
# output:
# - $2 is created if $1 exists
# ---------------------------------------------------------------------
function _iconv
{
if test "$1" = "-d"                            # delete $2 if it exists
then
  shift
  test -f "$2" && _cmd rm -f "$2"
fi    #

test -f "$1" && _cmd --save "$2" iconv -t ISO8859-1 -f IBM-1047 "$1"
}    # _iconv

# ---------------------------------------------------------------------
# --- customize a file using sed, and store it as a member
#     assumes $SED is defined by caller and holds sed command string
# $1: if -s then make sequential dataset, parm is removed when present
# $1: input file
# $2: output data set
# ---------------------------------------------------------------------
function _sedMVS
{
if test "$1" = "-s"
then  # sequential
  shift
  DsN="$2"
else  # PDS member
  # create member name
  DsN="$(basename $1)"                           # strip directory name
  DsN="${DsN%%.*}"                     # keep up to first . (exclusive)
  # add data set name
  DsN="$2($DsN)"
fi    #
TmP=${TMPDIR:-/tmp}/$(basename $1).$$
_cmd --repl $TmP sed "$SED" $1                    # sed '...' $1 > $TmP
_cmd mv $TmP "//'$DsN'"                         # move $TmP to data set
}    # _sedMVS

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

TmP=${TMPDIR:-/tmp}/$(basename $1).$$
_cmd --repl $TmP sed "$SED" $1                  # sed '...' $1 > $TmP
#test "$debug" && echo
#test "$debug" && echo "sed $SED 2>&1 $1 > $TmP"
#sed "$SED" $1 2>&1 > $TmP                       # sed '...' $1 > $TmP
_cmd mv $TmP ${2:-$1}                           # give $TmP actual name
test -n "$ExEc" && _cmd chmod a+x ${2:-$1}      # make executable
}    # _sed

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
unset BUILD BRANCH YAML reqPTF VERSION
# do NOT unset debug

# get startup arguments
while getopts B:b:c:p:?dP opt
do case "$opt" in
  B)   BUILD="$OPTARG";;
  b)   BRANCH="$OPTARG";;
  c)   YAML="$OPTARG";;
  d)   debug="-d";;
  P)   reqPTF="-P";;
  p)   VERSION="$OPTARG";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $(($OPTIND-1))

# set default values
BUILD=${BUILD:-unknown}
BRANCH=${BRANCH:-unknown}
VERSION=${VERSION:-unknown}

# set envvars
. $here/$cfgScript -c                         # call with shell sharing
if test $rc -ne 0
then
  # error details already reported
  echo "** ERROR $me '. $here/$cfgScript' ended with status $rc"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

service="$(cd $here/$service 2>&1;pwd)"    # make this an absolute path
mcsHlq=${HLQ}.${RFDSNPFX}.${FMID}          # RELFILE HLQ,  max 32 chars
ptfHLQ=${RFDSNPFX}.${FMID}                        # default HLQ for PTF
MLQ='@'                 # job results in $gimdtsHlq.$MLQ.*, max 2 chars
# fixed LLQs max 10 chars + 1 period (=2 char MLQ + 8 char LLQ)
SYSMOD=${gimdtsHlq}.$MLQ                    # PTF staging data set name
LINES=${gimdtsHlq}.LINES                     # line count data set name
TRACKS=${gimdtsHlq}.TRACKS                  # track count data set name
SYSPRINT=${gimdtsHlq}.SYSPRINT               # job output data set name
unset allParts                        # collect names of all parts here
today=$(date +%Y-%m-%d?%j)         # get date just once, yyyy-mm-dd?jjj
yyyymmdd=$(echo $today | sed 's/?.*//') # 10-character date, yyyy-mm-dd
julian7=$(echo $today | sed 's/-.*?//')  # 7-digit Julian date, yyyyddd
julian5=$(echo $julian7 | sed 's/^..//')   # 5-digit Julian date, yyddd
year=$(echo $today | sed 's/-.*//')                # 4-digit year, yyyy
copyright="Contributors to the Zowe Project. $year"         # copyright
#          ----+----1----+----2----+----3----+----4--      max 42 chars

# show input/output details
echo "-- input (relfile): $mcsHlq"
echo "-- input (service): $service"
echo "-- output:          $ship"

# remove output of previous run
test -d $ptf && _cmd rm -rf $ptf          # always delete ptf directory
_deleteDatasets "$gimdtsHlq"
# get ready to roll
_cmd mkdir -p $ptf

# determine what sysmod type to create (PTF/APAR/USERMOD)
_type

# clean up external input
_prepInput

# stage data of this PTF to be added to data of promoted PTFs
_stagePromote

# stage data to simplify redistribution of PTFs via IBM's Shopz
_stageShopz

# create headers for first and overflow sysmods
_headers

# create SMP/E MCS metadata for parts to package
_metaData

# stage JCL procedures & support REXX
_tools

# create parts in FB80 format (GIMDTS job)
_gimdts

# determine how to distribute parts across sysmods
_split

# merge header and parts (MERGE job)
_merge

# create install instructions
_readme

# zip up sysmod(s) & instructions
_zip

# we are done with these, clean up
_cmd cd $here                         # make sure we are somewhere else
_cmd rm -rf $ptf
_deleteDatasets "$gimdtsHlq"

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0                                                           # EXIT
