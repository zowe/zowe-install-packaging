#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# 5698-ZWE Copyright Contributors to the Zowe Project. 2019, 2019
#######################################################################

#% cut installed product in smaller chunks and pax them
#%
#% -?                 show this help message
#% -c smpe.yaml       use the specified config file
#% -d                 enable debug messages
#% -i inputReference  file holding input names (build output archives)
#%                    (used for documentation in package manifest)
#%
#% -c is required
#%
#% caller needs these RACF permits:
#% ($0)
#% TSO PE BPX.SUPERUSER        CL(FACILITY) ACCESS(READ) ID(userid)
#% TSO SETR RACLIST(FACILITY) REFRESH

# trashes $stage           directory with installed product
# creates $ussI/*          directory with pax files                 #*/
# creates $log/$manifest   manifest describing pax content
# creates $log/$delta      delta of current and previous manifest
# creates $log/fileSize    product file sizes
# creates $log/treeSize    product directory sizes
# creates $log/symLink     product symlinks
# creates $log/extAttr     product non-standard extattr bits
# creates $log/dataSet     product data sets and members
# creates $log/parts       parts known by SMP/E
# creates $log/partsDelta  parts known by SMP/E
# updates $log/$deltaHist  history of manifest deltas
# removes old manifest files

historical=history-            # prefix for historical data
delta=manifest-delta.txt       # delta of current and previous manifest
deltaHist=$historical$delta    # history of manifest deltas
fileSize=filesize.txt          # product file sizes
treeSize=treesize.txt          # product directory sizes
symLink=symlink.txt            # product symlinks
extAttr=extattr.txt            # product non-standard extattr bits
dataSet=dataset.txt            # product data sets and members
parts=parts.txt                # parts known by SMP/E
partsDelta=parts-delta.txt     # delta of current and previous parts
cfgScript=get-config.sh        # script to read smpe.yaml config data
csiScript=get-dsn.rex          # catalog search interface (CSI) script
here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug
# more defaults defined later, search for "date="

test "$debug" && echo
test "$debug" && echo "> $me $@"

# ---------------------------------------------------------------------
# --- split $stage into smaller directories that hold pax content
#
# If the previous run had more pax files than this run, SMP/E would
# not replace them, thus leaving old data in place which results in
# a convoluted picture. Therefore, we determine here how many pax
# directories were created previously, and ensure we match that number,
# if need be with empty ones. (A manifest is added before creating the
# pax file, so pax always has something to process.)
# ---------------------------------------------------------------------
function _split
{
test "$debug" && echo
test "$debug" && echo "> _split $@"

# count how many pax directories we created during previous run
prevCnt=0
test -e $split && prevCnt=$(ls -D $split/ | wc -w | sed 's/ //g')
test "$debug" && echo prevCnt=$prevCnt

# start with a clean slate
test -e $split && _cmd rm -rf $split
_cmd mkdir -p $split

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

cnt=0                           # counter, part of target pax file name
# let will: increase $cnt
# "echo 0$cnt" will: create a counter at least 2 chars long
# sed will: take the last 2 chars of the expanded counter

# CLI always seperate
let cnt=$cnt+1 ; file=${mask}$(echo 0$cnt | sed 's/.*\(..\)$/\1/')
_move $stage $split/$file "ls zowe-cli-*.zip"

# everything zlux
# > zlux-app-server has symlinks to zlux-server-framework & zss-auth
# > -> they must all be in the same archive
let cnt=$cnt+1 ; file=${mask}$(echo 0$cnt | sed 's/.*\(..\)$/\1/')
_move $stage $split/$file "find zlux-* -prune"
_move $stage $split/$file echo zss-auth

# all miscelaneous files in root and select directories
let cnt=$cnt+1 ; file=${mask}$(echo 0$cnt | sed 's/.*\(..\)$/\1/')
_move $stage $split/$file find . -level 0 ! -type d
_move $stage $split/$file echo ./files
_move $stage $split/$file echo ./install
_move $stage $split/$file echo ./licenses
_move $stage $split/$file echo ./scripts

# all but select files in api-mediation root
for f in $(find api-mediation -level 0 ! -type d | grep -v /enabler)
do
  let cnt=$cnt+1 ; file=${mask}$(echo 0$cnt | sed 's/.*\(..\)$/\1/')
  _move $stage $split/$file echo $f
done    # for f

# each remaining directory in root gets a separate pax file
for d in $(ls -D $stage)
do
  let cnt=$cnt+1 ; file=${mask}$(echo 0$cnt | sed 's/.*\(..\)$/\1/')
  _move $stage $split/$file echo $d
done    # for d

# verify everything is moved
echo "-- verifying split action"
orphan=$(ls -A $stage)
if test "$orphan"
then
  echo "** ERROR $me not all files are moved to $split"
  echo "$orphan"                          # quotes preserve line breaks
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# ensure we have at least the same number of pax files as previous run
test "$debug" && echo "$cnt ?< $prevCnt"
while test $cnt -lt $prevCnt
do
  let cnt=$cnt+1 ; file=${mask}$(echo 0$cnt | sed 's/.*\(..\)$/\1/')
  _cmd mkdir -p $split/$file
done    #

test "$debug" && echo "< _split"
}    # _split

# ---------------------------------------------------------------------
# --- move selected files
# $1: if --del then delete input directory after move, parm is removed
# $1: input directory, parm is removed
# $2: output directory (created if it does not exist), parm is removed
# $@: command to create a list of files to process, relative to $iDIR
# ---------------------------------------------------------------------
function _move
{
test "$debug" && echo
test "$debug" && echo "> _move $@"

unset DEL
# delete directory after content move ?
if test "$1" = "--del"
then
  shift
  DEL=1
fi    #

iDIR=$1
oDIR=$2
shift 2

echo "-- moving data from $iDIR to $oDIR"

# create output directory if it does not exist
_cmd mkdir -p $oDIR

# go to input directory
_cmd cd $iDIR

# show what will be moved
$@

# move data that matches filter
test "$debug" && echo
test "$debug" && echo "eval mv -R \$($@) $oDIR 2>&1"
eval "mv -R \$($@) $oDIR 2>&1"
test $? -ne 0 -a ! "$IgNoRe_ErRoR" && exit 8                     # EXIT

# return to previous directory
_cmd --null cd -

# delete input directory if requested
test "$DEL" && _cmd rmdir $1

test "$debug" && echo "< _move"
}    # _move

# ---------------------------------------------------------------------
# --- build manifest
# ---------------------------------------------------------------------
function _manifest
{
test "$debug" && echo
test "$debug" && echo "> _manifest"

echo "-- creating $log/$manifest"
# track content in manifest

# 1. root content, so SMP/E knows what to delete on cleanup
_cmd cd $stage
_cmd --repl $log/$manifest ls -A
# sample output:
# manifest.json
# mvs_explorer

# 2. track location of original input in manifest
if test "$in"
then
  test "$debug" && echo
  test "$debug" && echo "cat $in | sed 's!.*/!!;s/^/## /' 2>&1 >> $log/$manifest"
  # sed will remove $dirname and prefix with '## '
  cat $in | sed 's!.*/!!;s/^/## /' 2>&1 >> $log/$manifest
  test $? -ne 0 -a ! "$IgNoRe_ErRoR" && exit 8                   # EXIT
fi    #
# sample output:
# ## zowe-1.1.0.pax
# ## zowe-cli-package-1.1.0.zip

# 3. set aside all USS content for delta & reference
#-- only file name
# test "$debug" && echo
# test "$debug" && echo "find . | sed 's/^/# /' >> $log/tmp.$manifest"
# find . | sed 's/^/# /' 2>&1 >> $log/tmp.$manifest
# test $? -ne 0 -a ! "$IgNoRe_ErRoR" && exit 8                   # EXIT
#-- file name, file type, extended attribs & size (requires sorting)
test "$debug" && echo
test "$debug" && echo "for d in \$(find $stage -type d)"
for d in $(find $stage -type d)
do
  # SHORT: only keep useful part of dir (strip $stage, prefix with .)
  SHORT=.${d#$stage}
  # dir & symlink do not have extended attribs in ls -lE, add dummy
  # SED1: if pos 13-16 = '    ' then replace with '++++'
  SED1='s/^\(.\{12\}\)    \(.*\)$/\1++++\2/'
  # SED2: only keep first char (filetype: -,d,l) of permission flags
  #       and add 2 periods to the end (word 11 & 12 when no symlink)
  SED2='s/\(.\).\{9\}\(.*\)/\1\2 \. \./'
  # AWK: print only file type, extattr, file name, symlink, & size
  AWK='{if ($5 != "") printf("#USS %s %s '$SHORT'/%s %s %s %d\n" \
      ,$1,$2,$10,$11,$12,$6)}'

  ls -lAE $d | sed "$SED1" | sed "$SED2" | awk "$AWK" \
    2>&1 >> $log/tmp.$manifest
  test $? -ne 0 -a ! "$IgNoRe_ErRoR" && exit 8                   # EXIT
done    # for d
# sample output:
# #USS d ++++ ./mvs_explorer . . 8192
# #USS - -ps- ./zlux-app-server/bin/zssServer . . 1978368
# #USS l ++++ ./jes_explorer/server/node_modules/.bin/which -> ../which/bin/which 18

# append details in temporary manifest to actual manifest
# (sorted by path name, which is the 4th field)
_cmd --save $log/$manifest sort -k 4 $log/tmp.$manifest

# remove temporary manifest
test -e "$log/tmp.$manifest" && _cmd rm -f $log/tmp.$manifest 2>&1

# 4. set aside all MVS content for delta & reference
test "$debug" && echo
test "$debug" && echo "for d in \$(ls -D $mvs)"
for d in $(ls -D $mvs)
do
  # AWK: print only file name & size, using same format as #USS
  AWK='{if ($5 != "") printf("#MVS - ++++ '$d'(%s) . . %d\n",$9,$5)}'
  ls -l $mvs/$d | awk "$AWK" 2>&1 >> $log/$manifest
done    # for d
# sample output:
# #MVS - ++++ SZWEAUTH(ZWESIS01) . . 434176

test "$debug" && echo "< _manifest"
}    # _manifest

# ---------------------------------------------------------------------
# --- track delta in packaging manifests
# ---------------------------------------------------------------------
function _delta
{
test "$debug" && echo
test "$debug" && echo "> _delta $@"

dHist=$log/$deltaHist                  # make fully qualified file name
dNow=$log/$delta                       # make fully qualified file name

# get name of previous manifest, if any
prev=$(ls $log/${mask}.*.${tail} | tail -2 | head -1)
test "$debug"  && echo prev=$prev

# there is no previous manifest if the current one was returned
test "$debug" && echo
test "$debug" && echo "test $(basename $prev) ?= $manifest"
test "$(basename $prev)" = $manifest && unset prev

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# create/append delta log (verbose format)
_cmd --save $dHist echo ---- $(date)        # ---- must be on fist line
if test -z "$prev"
then
  echo -- skipped comparing $manifest against {none}
  _cmd --save $dHist echo -- skipped comparing $manifest against {none}
else
  echo -- comparing $manifest against $(basename $prev)
  _cmd --save $dHist echo -- comparing $manifest against $(basename $prev)
  _cmd --save $dHist echo
  _cmd --save $dHist echo -- these lines are only in $manifest
  _cmd --save $dHist comm -23 $log/$manifest $prev
  _cmd --save $dHist echo
  _cmd --save $dHist echo -- these lines are NOT in $manifest
  _cmd --save $dHist comm -13 $log/$manifest $prev
fi    #
_cmd --save $dHist echo
_cmd --save $dHist echo

# trim delta log to preserve space (cut oldest delta until limit met)
test "$debug" && echo "$(wc -l < $dHist) ?gt $maxDeltaLines"
while test $(wc -l < $dHist) -gt $maxDeltaLines
do
  # document what we are removing
  head -1 $dHist 2>&1 | sed 's/^----/-- removing manifest delta of/'
  # sample output:
  # -- removing manifest delta of Thu Apr 25 11:52:07 EDT 2019
  _cmd mv $dHist $dHist.old
  # awk skips first line (has ----) and starts printing from next ----
  # -> net result is that the first (oldest) delta results are removed
  _cmd --save $dHist awk '/1/{next} /^----/{f=1} f{print}' $dHist.old
  _cmd rm -f $dHist.old
done    # while maxDeltaLines

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

echo "-- creating $dNow"

# create condensed delta report for processing by other tools
# output format:
# ---- timestamp
# -- action { skipped ... | comparing ...}
# DEL line_only_in_previous_manifest
# NEW line_only_in_current_manifest
_cmd --repl $dNow echo ---- $(date)
if test -z "$prev"
then
  _cmd --save $dNow echo -- skipped comparing $manifest against {none}
else
  _cmd --save $dNow echo -- comparing $manifest against $(basename $prev)
  # no error handling, from $dHist we know comm command works
  comm -13 $log/$manifest $prev | sed 's/^/DEL /' >> $dNow
  comm -23 $log/$manifest $prev | sed 's/^/NEW /' >> $dNow
fi    #

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# get names of all saved manifests except the last x
prev=$(ls $log/${mask}.*.${tail} \
         | awk -v n=$hist '{if(NR>n) print a[NR%n]; a[NR%n]=$0}')
test "$debug" && echo prev=$prev

# remove oldest manifests to preserve space
test "$prev" && _cmd rm -f $prev

test "$debug" && echo "< _delta"
}    # _delta

# ---------------------------------------------------------------------
# --- gather data to assist with understanding product
# ---------------------------------------------------------------------
function _snapshot
{
test "$debug" && echo
test "$debug" && echo "> _snapshot $@"

# create file size snapshot to assist with altering split-logic
echo "-- creating $log/$fileSize"
test -f $log/$fileSize.tmp && _cmd rm -f $log/$fileSize.tmp
# expect output of ls -lA, show size of each line and add / to subdir
#   .:
#   total 62
#   -rwxr-xr-x   1 owner    group       size date name
for f in $(ls -DAR $stage | grep ":$" | sed 's/:$//')
do
  # loop through all directories and show size of files
  # sed-1 adds / to the end for directories (first char is d)
  # awk prints size, path and filename if there is a size
  # sed-2 trims common path to .
  ls -lA $f \
    | sed '/^d/ s!.*!&/!' \
    | awk '{if ($5 != "") printf("%12d %s/%s\n",$5,dir,$9)}' dir=$f \
    | sed "s!$stage!.!" \
    2>&1 >> $log/$fileSize.tmp
  # cannot test $? as it is only of the last pipe command
done    # for f
# sample output:
#         8192 ./api-mediation/
#     67952893 ./api-mediation/api-catalog-services.jar

# sort largest -> smallest
_cmd --repl $log/$fileSize sort -r $log/$fileSize.tmp

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# create directory size snapshot to assist with altering split-logic
echo "-- creating $log/$treeSize"
test -f $log/$treeSize && _cmd rm -f $log/$treeSize
# > this routine can be improved to visit each directory only once
# > right now subdirs are visted multiple times for size collection
# expect output of ls -lRA, add size of each line and print when done
#   .:
#   total 62
#   -rwxr-xr-x   1 owner    group       size date name
AWK='{if ($5 != "") cnt += $5} END {printf("%12d %s\n", cnt, dir)}'
for f in $(ls -DAR $stage | grep ":$" | sed 's/:$//')
do
  # loop through all directories and gather size of dir + subdirs
  ls -lRA $f \
    | awk "$AWK" dir=$f \
    | sed "s!$stage!.!" \
    2>&1 >> $log/$treeSize
  # cannot test $? as it is only of the last pipe command
done    # for f
# sample output:
#    407113528 .
#    251499356 ./api-mediation
#        15443 ./api-mediation/apiml-auth
#         6855 ./api-mediation/apiml-auth/lib
#        27148 ./api-mediation/scripts

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# create symlink snapshot to assist with altering split-logic
echo "-- creating $log/$symLink"
test -f $log/$symLink && _cmd rm -f $log/$symLink
# sed replaces everything up to $stage (incl) with ., leaving symlink info
test "$(find $stage -type l)" &&
  ls -l $(find $stage -type l) | sed "s!.*$stage!.!" > $log/$symLink
# cannot test $? as it is only of the last pipe command
# sample output:
# ./jes_explorer/server/node_modules/.bin/which -> ../which/bin/which

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# create extattr snapshot to assist with tracking special files
echo "-- creating $log/$extAttr"
test -f $log/$extAttr && _cmd rm -f $log/$extAttr
# awk prints only extattr & path
# sed trims common path to .
test "$(find $stage -ext a -o -ext p)" && \
  ls -E $(find $stage -ext a -o -ext p) \
    | awk '{print $2, $10}' \
    | sed "s!$stage!.!" \
    > $log/$extAttr
# cannot test $? as it is only of the last pipe command
# sample output:
# -ps- ./zlux-app-server/bin/zssServer

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# create data set snapshot to assist with tracking members
echo "-- creating $log/$dataSet"
test -f $log/$dataSet && _cmd rm -f $log/$dataSet
# get data set list (no debug mode to avoid debug messages)
datasets=$($here/$csiScript "${mvsI}.**")
# returns 0 for match, 1 for no match, 8 for error
if test $? -gt 1
then
  echo "$datasets"                       # variable holds error message
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
# get member list
for dsn in $datasets
do
  test "$debug" && echo
  test "$debug" && echo "tsocmd \"listds '$dsn' members\""
  # awk will print line with $dsn and all lines folowing --MEMBER
  tsocmd "listds '$dsn' members" 2>/dev/null \
    | awk "/^$dsn/{print} /^--MEMBERS/{f=1;next} f{print}" \
    >> $log/$dataSet
  # cannot test $? as it is only of the last pipe command
done    # for dsn
# sample output:           # note: alias shows as "member ALIAS(alias)"
# BLD.ZOWE.AZWE110.IN.SZWEAUTH
#   ZWESIS01

test "$debug" && echo "< _snapshot"
}    # _snapshot

# ---------------------------------------------------------------------
# --- create list of parts known by SMP/E
# format:  1         2         3
# 123456789012345678901234567890
# DD...... PART.... SIZE
# ---------------------------------------------------------------------
function _parts
{
test "$debug" && echo
test "$debug" && echo "> _parts $@"

echo "-- creating $log/$parts"

# keep previous parts list without file size
test -f $log/$parts && \
  _cmd --repl $log/$parts.old cut -c 1-17 $log/$parts

# clear the stage
test -f $log/$parts.tmp && _cmd rm -f $log/$parts.tmp

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# add MVS parts
test "$debug" && echo
test "$debug" && echo "for d in \$(ls -D $mvs)"
for d in $(ls -D $mvs)
do
  # AWK: print only DD name, file name & file size
  AWK='{if ($5 != "") printf("%-8s %-8s %d\n","'$d'",$9,$5)}'
  ls -l $mvs/$d | awk "$AWK" 2>&1 >> $log/$parts.tmp
done    # for d
# sample output:
# SZWEAUTH ZWESIS01 434176

# add USS parts
d='SZWEZFS'                           # all USS parts belong in this DD
# AWK: print only DD name, file name & file size
AWK='{if ($5 != "") printf("%-8s %-8s %d\n","'$d'",$9,$5)}'
ls -l $ussI | awk "$AWK" 2>&1 >> $log/$parts.tmp
# sample output:
# SZWEZFS  ZWEPAX01 11870208

# sort to simplify automated processing
_cmd --repl $log/$parts sort $log/$parts.tmp

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# bail on duplicate entries
# (take only member names, sort, then sort unique with input check)
cut -c 10-17 $log/$parts 2>&1 | sort 2>&1 | sort -uc 2>&1
if test $? -ne 0              # note: sort -uc stops at first duplicate
then
  # error details already reported
  echo "** ERROR duplicate part name encountered"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

echo "-- creating $log/$partsDelta"

# get current parts list without file size
_cmd --repl $log/$parts.tmp cut -c 1-17 $log/$parts

# use shortcut names
pOld=$log/$parts.old
pNew=$log/$parts.tmp
pDelta=$log/$partsDelta

# create condensed delta report for processing by other tools
# output format:
# ---- timestamp
# -- action { skipped ... | comparing ...}
# DEL line_only_in_previous_parts_list
# NEW line_only_in_current_parts_list
_cmd --repl $pDelta echo ---- $(date)
if test -e "$log/$parts.old"
then
  _cmd --save $pDelta echo -- comparing parts list against previous
  # no error handling, we know files exist
  comm -13 $pNew $pOld | sed 's/^/DEL /' >> $pDelta
  comm -23 $pNew $pOld | sed 's/^/NEW /' >> $pDelta
else
  _cmd --save $pDelta echo -- skipped comparing parts list
fi    #

test -f $log/$parts.old && _cmd rm -f $log/$parts.old
test -f $log/$parts.tmp && _cmd rm -f $log/$parts.tmp

test "$debug" && echo "< _parts"
}    # _parts

# ---------------------------------------------------------------------
# --- pax a whole staging directory
# $1: directory to pax
# ---------------------------------------------------------------------
function _pax
{
test "$debug" && echo
test "$debug" && echo "> _pax $@"

paxFile="$ussI/${1}"

# go to directory to pax
_cmd cd $split/$1

echo "-- creating $paxFile"
# pax
#  -w                  write
#  -f ${paxfile}       output file
#  -s#${paxdir}##      substitute (strip build-specific root dir)
#  -o saveext          extended USTAR format
#  -px                 preserve extended attributes
#  ${paxmask}          input filter
paxOpt="-w -f $paxFile -s#$(pwd)## -o saveext -px $(ls -A)"
_cmd pax $paxOpt

# return to original directory
_cmd --null cd -

test "$debug" && echo "< _pax"
}    # _pax

# ---------------------------------------------------------------------
# --- show size of argument & compare to max PTF size
# $1: file or directory to process (sub-directories are included)
# ---------------------------------------------------------------------
function _size
{
test "$debug" && echo
test "$debug" && echo "> _size $@"

# sum size of all parts
AWK='{ if ($5 != "") bytes += $5} END {printf "%d",bytes}'
bytes=$(ls -lRA $1 | awk "$AWK")

# get size in different units (megabytes, cylinders)
# let is no good with 0 > result < 1, fabricate result if needed
#   1 MB = 1024*1024 = 1048576
if test $bytes -lt 1048576
then                                            # actual less than 1 MB
  MB=1
else
  _cmd let MB=$bytes/1048576
fi    #
_cmd let CYL=$MB*100/80                                # 1 CYL = 0.8 MB

# IBM: max PTF size is 5,000,000 * 80 bytes (including SMP/E metadata)
# let is no good with 0 > result < 1, fabricate result if needed
#   100% = 5mio*80 -> 1% = (5mio*80)/100 = 4mio bytes
_cmd let onePtfPercentInBytes=maxPtfLines*8/10
if test $bytes -lt $onePtfPercentInBytes
then                                              # actual less than 1%
  percent=1
else
  _cmd let percent=$bytes/$onePtfPercentInBytes
fi    #

# report size
AWK='-- %s has %d bytes (%.1f MB, %.1f CYL), %.1f%% of max PTF size\n'
AWK='{printf "'$AWK'",$1,$2,$3,$4,$5}'
echo $(basename $1) $bytes $MB $CYL $percent | awk "$AWK"

# bail when >= x% of max PTF size
if test $percent -ge $maxPtfPercent
then
  echo "** ERROR $me $MB MB exceeds ${maxPtfPercent}%" \
    "of the maximum PTF size"
  echo "   rework the split logic in $me to correct this"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

test "$debug" && echo "< _size"
}    # _size

# ---------------------------------------------------------------------
# --- stage data set members for reporting
# ---------------------------------------------------------------------
function _stageMembers
{
test "$debug" && echo
test "$debug" && echo "> _stageMembers $@"

# show everything in debug mode
test "$debug" && $here/$csiScript -d "${mvsI}.**"
# get data set list (no debug mode to avoid debug messages)
datasets=$($here/$csiScript "${mvsI}.**")
# returns 0 for match, 1 for no match, 8 for error
if test $? -gt 1
then
  echo "$datasets"                       # variable holds error message
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# clean up before we start
test -e $mvs && _cmd rm -rf $mvs

# copy data sets
for dsn in $datasets
do
  llq=${dsn##*.}                         # keep from last . (exclusive)
  test "$debug" && echo llq=$llq

  _cmd mkdir -p $mvs/$llq
  # Note: no problem if lmods get mangled, all we need is name & size
  _cmd cp -U "//'$dsn'" $mvs/$llq            # -U: keep names uppercase
done    # for dsn

test "$debug" && echo "< _stageMembers"
}    # _stageMembers

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
unset YAML in
# do NOT unset debug

# get startup arguments
while getopts c:i:?d opt
do case "$opt" in
  c)   YAML="$OPTARG";;
  d)   debug="-d";;
  i)   in="$OPTARG";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR faulty startup argument: $@"
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

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

mask=ZWEPAX                                          # output file mask
date=$(date '+%Y%m%d_%H%M%S')                        # yyyymmdd_hhmmss
tail='manifest.txt'
manifest=${mask}.${date}.${tail}                     # manifest file

# show input/output details
echo "-- input:  $stage"
echo "-- output: $ussI"

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# copy all MVS parts to USS for reporting
_stageMembers

# set owner, & permissions for input to ensure consistency
_super chown -R 0:0 $stage
_super chmod -R 755 $stage

# create packaging manifest
_manifest
# document delta with previous manifest
_delta
# gather data to assist with understanding product
_snapshot

# split $stage into smaller chunks, place the result in $split/*
_split

# remove data of previous run (if any) ...
test -e "$ussI" && _cmd rm -rf $ussI
# ... and get ready to roll
_cmd mkdir -p $ussI

# loop through $split/* directories to
# - add manifest
# - create pax
# - check size
for d in $(ls $split)
do
  _cmd cp $log/$manifest $split/$d/
  _pax $d
  _size $paxFile
done    # for d

# create list of parts known by SMP/E
_parts

# we are done with these, clean up
_cmd cd $here                         # make sure we are somewhere else
_cmd rm -rf $stage
_cmd rm -rf $split
_cmd rm -rf $mvs

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0                                                           # EXIT
