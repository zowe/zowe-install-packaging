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

#% package prepared product as base FMID (++FUNCTION)
#%
#% -?                 show this help message
#% -c smpe.yaml       use the specified config file
#% -d                 enable debug messages
#%
#% -c is required

# require $mvsI.*     data sets with installed product
# require $ussI/*     directory with product pax files              #*/
# removes $mvsI.*     data sets with installed product
# removes $ussI/*     directory with product pax files              #*/
# creates $mcsHlq.*   RELFILEs & SMPMCS

# more definitions in main()
prefix=ZWE                     # product prefix
parts=parts.txt                # parts known by SMP/E
copied=copied.txt              # parts copied to RELFILEs
mcs=SMPMCS.txt                 # SMPMCS header
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
# --- create & populate rel files
# ---------------------------------------------------------------------
function _relFiles
{
test "$debug" && echo && echo "> _relFiles $@"

# remove RELFILEs of previous run

# show everything in debug mode
test "$debug" && $here/$csiScript -d "${mcsHlq}.F*"
# get data set list (no debug mode to avoid debug messages)
datasets=$($here/$csiScript "${mcsHlq}.F*")
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

# create RELFILEs

partsX=$log/$parts
copiedX=$log/$copied
test -f $copiedX && _cmd rm -f $copiedX      # delete verification file

# parse parts.txt to get part names (& save in copied.txt to verify)
# sample input:
# SZWESAMP ZWE1SMPE 12872

# TODO dynamically determine required RELFILE size
# TODO save RELFILE info for PD
# TODO save target & DLIB info for PD (data in ZWE3ALOC)
# TODO ensure ZWE3ALOC target allocations match community build

# +----------------------------------------------------------------+
# | ************************************************************** |
# | * Do NOT change DCB or size data without contacting an IBM   * |
# | * employed build engineer as Shopz has specific requirements * |
# | ************************************************************** |
# +----------------------------------------------------------------+

# F1 - only SMP/E install related
dd="S${prefix}SAMP"
sed -n '/^'$dd' /p' $partsX \
  | grep -e ${prefix}[[:digit:]] -e ${prefix}MKDIR > $copiedX.list
# no error trapping (for last pipe anyway)
_cmd --save $copiedX cat $copiedX.list
list=$(awk '{print $2}' $copiedX.list)              # only member names
_copyMvsMvs "${mvsI}.$dd" "${mcsHlq}.F1" "FB" "80" "8800" "PO" "5,5"

# F2 - all sample members except SMP/E install related
dd="S${prefix}SAMP"
sed -n '/^'$dd' /p' $partsX \
  | grep -v ${prefix}[[:digit:]] \
  | grep -v ${prefix}MKDIR > $copiedX.list
# no error trapping (for last pipe anyway)
_cmd --save $copiedX cat $copiedX.list
list=$(awk '{print $2}' $copiedX.list)              # only member names
_copyMvsMvs "${mvsI}.$dd" "${mcsHlq}.F2" "FB" "80" "8800" "PO" "5,5"
dd="S${prefix}EXEC"
sed -n '/^'$dd' /p' $partsX > $copiedX.list         # no error trapping
_cmd --save $copiedX cat $copiedX.list
list=$(awk '{print $2}' $copiedX.list)              # only member names
_copyMvsMvs "${mvsI}.$dd" "${mcsHlq}.F2" "FB" "80" "8800" "PO" "5,5"

# F3 - all load modules
dd="S${prefix}AUTH"
sed -n '/^'$dd' /p' $partsX > $copiedX.list         # no error trapping
_cmd --save $copiedX cat $copiedX.list
list=$(awk '{print $2}' $copiedX.list)              # only member names
_copyMvsMvs "${mvsI}.$dd" "${mcsHlq}.F3" "U" "**" "6144" "PO" "30,5"
dd="S${prefix}LOAD"
sed -n '/^'$dd' /p' $partsX > $copiedX.list         # no error trapping
_cmd --save $copiedX cat $copiedX.list
list=$(awk '{print $2}' $copiedX.list)              # only member names
_copyMvsMvs "${mvsI}.$dd" "${mcsHlq}.F3" "U" "**" "6144" "PO" "30,5"

# F4 - all USS files
# half-track on 3390 DASD is 27998 bytes
# record length 6999 fits 4 records per half-track, with 2 bytes left
# subtract 4 for variable record length field gives LRECL(6995)
dd="S${prefix}ZFS"
sed -n '/^'$dd' /p' $partsX > $copiedX.list         # no error trapping
_cmd --save $copiedX cat $copiedX.list
list=$(awk '{print $2}' $copiedX.list)              # only member names
_copyUssMvs $ussI "${mcsHlq}.F4" "VB" "6995" "6999" "PO" "9000,300"

# if copied.txt matches parts.txt then everything is copied

_cmd --repl $partsX.list sort $partsX
_cmd --repl $copiedX.list sort $copiedX

# compare both lists
test "$debug" && echo
test "$debug" && \
  echo "test -n \"\$(comm -3 $copiedX.list $partsX.list)\""
if test -n "$(comm -3 $copiedX.list $partsX.list)"
then
  echo "** ERROR not all parts copied into RELFILEs"
  echo "   these files are copied but are not defined in $partsX"
  _cmd comm -23 $copiedX.list $partsX.list     # safety, should not hit
  echo "   these files are defined in $partsX but are not copied"
  _cmd comm -13 $copiedX.list $partsX.list
  _cmd rm -f $copiedX.list $partsX.list
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  test "$debug" && echo "all files copied into RELFILEs"
fi    #

#cleanup
test -f $copiedX && _cmd rm -f $copiedX
test -f $partsX.list && _cmd rm -f $partsX.list
test -f $copiedX.list && _cmd rm -f $copiedX.list

test "$debug" && echo "< _relFiles"
}    # _relFiles

# ---------------------------------------------------------------------
# --- create SMPMCS
# ---------------------------------------------------------------------
function _smpmcs
{
test "$debug" && echo && echo "> _smpmcs $@"

echo "-- create SMPMCS"

file="$here/$mcs"                                               # input
dsn="${mcsHlq}.SMPMCS"                                         # output

year=$(date '+%Y')                                               # YYYY
test "$debug" && year=$year
julian=$(date +%Y%j)                                          # YYYYddd
test "$debug" && julian=$julian

# validate/create target data set
if test -z "$fmidVolser"
then
  $here/$allocScript $dsn "FB" "80" "PS" "1,1"
else
  $here/$allocScript -V "$fmidVolser" $dsn "FB" "80" "PS" "1,1"
fi    #
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
rc=$?
if test $rc -eq 0
then
  # customize SMPMCS
  SED="s/\[FMID\]/$FMID/g"
  SED="$SED;s/\[YEAR\]/$year/g"
  SED="$SED;s/\[DATE\]/$julian/g"
  SED="$SED;s/\[RFDSNPFX\]/$RFDSNPFX/g"
  SED="$SED;/^ #.*/d"                     # remove source-only comments
  _cmd --repl $file.new sed "$SED" $file

  # TODO dynamically add parts processed by _relFiles()

  # TODO SMPMCS SUP existing service / FMIDs

  # move the customized file
  _cmd mv $file.new "//'$dsn'"
elif test $rc -eq 1
then
  echo "** ERROR $me data set $dsn exists with wrong DCB"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  # Error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

test "$debug" && echo "< _smpmcs"
}    # _smpmcs

# ---------------------------------------------------------------------
# --- verify that SMPMCS matches parts present
# ---------------------------------------------------------------------
function _verify
{
test "$debug" && echo && echo "> _verify $@"

echo "-- verify SMPMCS matches staged files"

# parse SMPMCS and keep SYSLIB name & part name, sorted
# sample input:
# ++SAMP(ZWE1SMPE)     SYSLIB(SZWESAMP) DISTLIB(AZWESAMP) RELFILE(1) .
# sample output:
# SZWESAMP ZWE1SMPE
# - tr will change all round brackets to semi-colons
# - awk will only take lines begininng with + and have keyword SYSLIB,
#   split fields at a semi-colon, and print field 4 and 2
mcsX="$here/$mcs"
cMd="cat $mcsX"
cMd="$cMd | tr \(\) ::"
cMd="$cMd | awk -F\":\" '/^\+.*SYSLIB/ {printf(\"%-8s %-8s\n\",$4,$2)}'"
cMd="$cMd | sort"
cMd="$cMd > $mcsX.list"
test "$debug" && echo
test "$debug" && echo $cMd
cat $mcsX | tr \(\) :: \
  | awk -F":" '/^\+.*SYSLIB/ {printf("%-8s %-8s\n",$4,$2)}' | sort \
  > $mcsX.list
# no error trapping (for last pipe anyway)

# parse parts.txt and keep SYSLIB name & part name, sorted
# sample input:
# SZWESAMP ZWE1SMPE 12872
# sample output:
# SZWESAMP ZWE1SMPE
partsX="$log/$parts"
# _cmd chokes on multiple quotes
cMd="awk '{printf(\"%-8s %-8s\n\",$1,$2)}' $partsX 2>&1 > $partsX.list"
test "$debug" && echo
test "$debug" && echo $cMd
awk '{printf("%-8s %-8s\n",$1,$2)}' $partsX 2>&1 > $partsX.list
status=$?

if test $status -ne 0
then
    echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# compare both lists
test "$debug" && echo
test "$debug" && echo "test -n \"\$(comm -3 $mcsX.list $partsX.list)\""
if test -n "$(comm -3 $mcsX.list $partsX.list)"
then
  echo "** ERROR SMPMCS does not match list of actual parts"
  echo "   these definitions are in $mcsX but the files do not exist"
  _cmd comm -23 $mcsX.list $partsX.list
  echo "   these files exist but there is no definition in $mcsX"
  _cmd comm -13 $mcsX.list $partsX.list
  _cmd rm -f $mcsX.list $partsX.list
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  test "$debug" && echo "SMPMCS matches staged files"
fi    #

# cleanup
test -f $mcsX.list && _cmd rm -f $mcsX.list
test -f $partsX.list && _cmd rm -f $partsX.list

test "$debug" && echo "< _verify"
}    # _verify

# ---------------------------------------------------------------------
# --- copy MVS members defined in $list to specified data set
# $1: input data set name
# $2: output data set name
# $3: record format; {FB | U | VB}
# $4: logical record length, use ** for RECFM(U)
# $5: block size
# $6: data set organisation; {PO | PS}
# $7: space in tracks; primary[,secondary]
# ---------------------------------------------------------------------
function _copyMvsMvs
{
test "$debug" && echo && echo "> _copyMvsMvs $@"

echo "-- populate $2 with $1"

# create target data set
if test -z "$fmidVolser"
then
  $here/$allocScript -B "$5" "$2" "$3" "$4" "$6" "$7"
else
  $here/$allocScript -V "$fmidVolser" -B "$5" "$2" "$3" "$4" "$6" "$7"
fi    #
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
rc=$?
if test $rc -eq 0
then
  for member in $list
  do
    test "$debug" && echo member=$member

    # TODO test if $1($member) exists

    unset X                   # -X is required for copying load modules
    test "$3" = "U" && X="-X"
    # cp -X requires z/OS V2R2 UA96711, z/OS V2R3 UA96707 (August 2018)
    _cmd cp $X "//'$1($member)'" "//'$2($member)'"

    # TODO build SMPMCS data for this part

  done    # for file
elif test $rc -eq 1
then
  echo "** ERROR $me data set $2 exists with wrong DCB"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  # Error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

test "$debug" && echo "< _copyMvsMvs"
}    # _copyMvsMvs

# ---------------------------------------------------------------------
# --- copy USS files defined in $list to specified data set
# $1: input path
# $2: output data set name
# $3: record format; {FB | U | VB}
# $4: logical record length, use ** for RECFM(U)
# $5: block size
# $6: data set organisation; {PO | PS}
# $7: space in tracks; primary[,secondary]
# ---------------------------------------------------------------------
function _copyUssMvs
{
test "$debug" && echo && echo "> _copyUssMvs $@"

echo "-- populate $2 with $1"

# validate/create target data set
if test -z "$fmidVolser"
then
  $here/$allocScript -B "$5" "$2" "$3" "$4" "$6" "$7"
else
  $here/$allocScript -V "$fmidVolser" -B "$5" "$2" "$3" "$4" "$6" "$7"
fi    #
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
rc=$?
if test $rc -eq 0
then
for file in $list
  do
    test "$debug" && echo file=$file
    if test ! -f "$1/$file" -o ! -r "$1/$file"
    then
      echo "** ERROR $me cannot access $file"
      echo "ls -ld \"$1/$file\""; ls -ld "$1/$file"
      test ! "$IgNoRe_ErRoR" && exit 8                           # EXIT
    fi    #

    unset X                   # -X is required for copying load modules
    test "$3" = "U" && X="-X"
    # cp -X requires z/OS V2R2 UA96711, z/OS V2R3 UA96707 (August 2018)
    _cmd cp $X "$1/$file" "//'$2(${file%%.*})'"   # %%.* = no extension

    # TODO build SMPMCS data for this part

  done    # for file
elif test $rc -eq 1
then
  echo "** ERROR $me data set $2 exists with wrong DCB"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  # Error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

test "$debug" && echo "< _copyUssMvs"
}    # _copyUssMvs

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

# show input/output details
echo "-- input MVS: $mvsI"
echo "-- input USS: $ussI"
echo "-- output:    $mcsHlq"

# ensure SMPMCS matches staged content
_verify
# create RELFILEs
_relFiles
# create SMPMCS
_smpmcs

# we are done with these, clean up
_cmd cd $here                         # make sure we are somewhere else
_cmd rm -rf $ussI
_deleteDatasets "$mvsI"

echo "-- completed $me 0"
test "$debug" && echo "< $me 0"
exit 0                                                           # EXIT
