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

# Set SMP/E packaging variables based on config file.
#
# CALLED WITH SHELL SHARING (. script.sh), set $rc to indicate error
#
# Arguments:
# cfgArg  caller startup argument to pass in config file, e.g. -c
# vrmArg  (optional) caller startup argument to pass in VRM, e.g. -v
#
# Expected globals:
# $IgNoRe_ErRoR $debug $YAML $VRM
#
# Optional globals:
# $fmid1 fmid2 $HLQ $ROOT
#
# Unconditional set:
# all variables in $YAML, see function _parseConfiguationFile
#
# Conditional set:
# $YAML  ${ROOT:-$dfltROOT}/$FMID/$dfltCnfg
#
# Alters:
# $line $key $section $value $default $rc $saved_me
# $dfltFmid1 $dfltFmid2 $dfltHLQ $dfltROOT $dfltCnfg
#
# $rc:
# 0: all good
# 8: error

dfltFmid1=A                    # default first character of FMID
dfltFmid2=ZWE                  # default FMID 3-character ID
dfltHLQ=BLD                    # default high level qualifier
dfltROOT=/bld/smpe             # default root directory
dfltCnfg=smpe.yaml             # default config file name
saved_me=$me                   # remember original $me
me=get-config.sh               # no $(basename $0) with shell sharing
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- write configuration file
# $1: file to write
# ---------------------------------------------------------------------
function _writeConfiguationFile
{
test "$debug" && echo && echo "> _writeConfiguationFile $@"

test "$debug" && echo
test "$debug" && echo "cat <<EOF 2>&1 >$1"
# - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * -
# TODO KEEP IN SYNC WITH _parseConfiguationFile
cat <<EOF 2>&1 >$1
#
# configuration file for Zowe SMP/E packaging
#
# base section MUST be first as defaults for other sections rely on it
base:
  # (required) product version/release/modification
  vrm=$VRM
  # (required) product FMID
  fmid=$FMID
  # (required) product root directory
  root=$ROOT
  # (required) product high level qualifier
  hlq=$HLQ
install:
  # number of historical logs to keep
  history=
  # log directory
  log=
  # temporary directory to extract archives before install
  extract=
  # semi-temporary directory where to install product
  stage=
  # HLQ holding product MVS data sets (= SMP/E input)
  outMVS=
  # directory holding product USS files (= SMP/E input)
  outUSS=
split:
  # absolute maximum number of lines in a PTF
  ptfLines=
  # halt if pax file reaches x% of maximum PTF size
  ptfPercent=
  # limit historical manifest delta log to x lines
  deltaLines=
  # temporary directory to stage MVS members for reporting
  mvs=
  # temporary directory to split product in chunks
  split=
fmid:
  # RELFILE data set name prefix, SMP/E expects #hlq.$RFDSNPFX.$FMID.Fx
  RFDSNPFX=
gimzip:
  # high level qualifier for GIMZIP work files
  gimzipHlq=
  # directory holding SMP/E pax & readme (also used for staging)
  gimzip=
  # temporary directory holding config data & symlinks
  scratch=
  # Java home directory, default uses existing JAVA_HOME if set
  JAVA_HOME=
  # SMP/ E home directory, default uses existing SMP_HOME if set
  SMP_HOME=
EOF
# - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * -
if test $? -ne 0
then
  echo "** ERROR $me creating $1 failed"
  echo "ls -ld \"$1\""; ls -ld "$1"
  rc=8
fi    #

test "$debug" && echo "< _writeConfiguationFile $rc"
}    # _writeConfiguationFile

# ---------------------------------------------------------------------
# --- parse configuration file
# $1: file to parse
# ---------------------------------------------------------------------
function _parseConfiguationFile
{
test "$debug" && echo && echo "> _parseConfiguationFile $@"

unset section                # ensure we evaluate something we have set

while read line
do
  # Leading blanks are already stripped by read
  test -z "${line%%#*}" && continue      # skip line if first char is #
  test "$debug" && echo "line    $line"

  key=${line%%=*}                      # keep up to first = (exclusive)
  test "$debug" && echo "key     $key"
  if test "$(echo $key | grep :$)"         # is last char of $key a : ?
  then                                     # yes -> new section
    section=${key%%:}                  # keep up to first : (exclusive)
    test "$debug" && echo "section $section"
  else                                     # no -> key=value pair
    value=${line#*=}                    # keep from first = (exclusive)
    test "$debug" && echo "value   $value"

# - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * -
    # TODO KEEP IN SYNC WITH _writeConfiguationFile
    # format: _export section key environment_variable default_value
# base
    _export base    vrm        VRM
    _export base    fmid       FMID
    _export base    root       ROOT
    _export base    hlq        HLQ
# install
    _export install history    hist          5              # permanent
    _export install log        log           ${ROOT}/logs   # permanent
    _export install extract    extract       ${ROOT}/extract # internal
    _export install stage      stage         ${ROOT}/stage  # pass
    _export install outMVS     mvsI          ${HLQ}.BLD     # output
    _export install outUSS     ussI          ${ROOT}/BLD    # output
# split
    _export split   ptfLines   maxPtfLines   5000000        # permanent
    _export split   ptfPercent maxPtfPercent 90             # permanent
    _export split   deltaLines maxDeltaLines 30000          # permanent
    _export split   mvs        mvs           ${ROOT}/mvs    # internal
    _export split   split      split         ${ROOT}/split  # internal
# fmid
    _export fmid    RFDSNPFX   RFDSNPFX      ZOWE           # output
# gimzip
    _export gimzip  gimzipHlq  gimzipHlq     ${HLQ}.GIMZIP  # internal
    _export gimzip  gimzip     gimzip        ${ROOT}/gimzip # output
    _export gimzip  scratch    scratch       \
              $(echo ${ROOT}/work | tr [:lower:] [:upper:]) # internal
    _export gimzip  JAVA_HOME  JAVA_HOME     \
              ${JAVA_HOME:-$(find /usr/lpp/java -type d -level 0 \
                             | grep /J.*[^_64]$ | tail -1)} # permanent
    _export gimzip  SMP_HOME   SMP_HOME      \
                                  ${SMP_HOME:-/usr/lpp/smp} # permanent
# pd
# service
# - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * - * -

  fi    # process key=value
done < $1    # while read

test "$debug" && echo "< _parseConfiguationFile $rc"
}    # parseConfiguationFile

# ---------------------------------------------------------------------
# --- set and export environment variable if section and key match
#     assumes $section $key $value are set
# $1: section must match this value
# $2: key must match this value
# $3: environment variable that will be set and exported
# $4: (optional) default value
# ---------------------------------------------------------------------
function _export
{
 if test "$section" = $1 -a "$key" = $2
 then
   # Is default value used?
   unset default
   test -z "$value" && default="   # default"

   # Export
   test "$debug" && echo "eval export $3=${value:-$4} 2>&1 $default"
   eval export $3="${value:-$4}" 2>&1

   if test $? -eq 0
   then
     test "$LOG_FILE" && echo "  $3=${value:-$4} $default" >> $LOG_FILE
   else
     # Error details already reported
     echo "** ERROR $me export $3=${value:-$4} failed"
     rc=8
   fi    #
 fi    # section & key match
}    # _export

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing
# Ensure the rc variable is null
unset rc

# Write header to log file, if present
test "$LOG_FILE" && echo "-------------------------------" >> $LOG_FILE
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE
test "$LOG_FILE" && echo "$(uname -Ia) -- $(date)" >> $LOG_FILE
test "$LOG_FILE" && echo "$(id)" >> $LOG_FILE

# Input validation, do not use elif so all tests run
if test -z "$YAML$VRM"
then
  if test "$2"
  then
    echo "** ERROR $me environment variable YAML or VRM must be set"
    echo "see $(basename $0) startup arguments $1 and $2"
  else
    echo "** ERROR $me environment variable YAML must be set"
    echo "see $(basename $0) startup argument $1"
  fi    #
  rc=8
fi    #

if test "$VRM"
then
  # VRM can contain letters; A=10, B=11, ..., Z=35
  # length <> 3 (test len+1) ? non-alpha/numeric ?
  if test "$(echo $VRM | wc -c)" -ne 4 -o \
      "$(echo $VRM | sed 's/[[:alnum:]]//g')"
  then
    echo "** ERROR $me $VRM is not a valid VRM velue"
    rc=8
  fi    #
fi    #

if test "$fmid1"
then
  # length <> 1 (test len+1) ? non-alpha ?
  if test "$(echo $fmid1 | wc -c)" -ne 2 -o \
    "$(echo $fmid1 | sed 's/[[:alpha:]]//g')"
  then
    echo "** ERROR $me $fmid1 is not a valid FMID first character"
    rc=8
  fi    #
fi    #

if test "$fmid2"
then
  # length <> 3 (test len+1) ? non-alpha/numeric ?
  if test "$(echo $fmid2 | wc -c)" -ne 4 -o \
    "$(echo $fmid2 | sed 's/[[:alnum:]]//g')"
  then
    echo "** ERROR $me $fmid2 is not a valid FMID 3-character ID"
    rc=8
  fi    #
fi    #

# no point validating $HLQ, will be created if needed
# no point validating $ROOT, will be created if needed
# no point validating $YAML, will be created if needed

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# uppercase where needed
test "$VRM" && VRM=$(echo $VRM | tr [:lower:] [:upper:])
test "$fmid1" && fmid1=$(echo $fmid1 | tr [:lower:] [:upper:])
test "$fmid2" && fmid2=$(echo $fmid2 | tr [:lower:] [:upper:])
test "$HLQ" && HLQ=$(echo $HLQ | tr [:lower:] [:upper:])

# create FMID name
# (will be faulty if $VRM is not set, fixed once we read $YAML)
export FMID=${fmid1:-$dfltFmid1}${fmid2:-$dfltFmid2}$VRM
test "$debug" && echo FMID=$FMID

# update base to support multiple FMIDs simultaneously
ROOT=${ROOT:-$dfltROOT}
ROOT=${ROOT%/$FMID}/$FMID     # ${}: keep up to last /$FMID (exclusive)
test "$debug" && echo ROOT=$ROOT
HLQ=${HLQ:-$dfltHLQ}
HLQ=${HLQ%.$FMID}.$FMID       # ${}: keep up to last .$FMID (exclusive)
test "$debug" && echo HLQ=$HLQ

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

test -z "$YAML" && YAML=$ROOT/$dfltCnfg
export YAML
test "$debug" && echo YAML=$YAML

# Create config file
if test -z "$rc"                             # only if no rc set so far
then
  if test -f "$YAML"
  then                                                   # $YAML exists
    if test ! -r "$YAML"
    then
      echo "** ERROR $me cannot read $YAML"
      echo "ls -ld \"$YAML\""; ls -ld "$YAML"
      rc=8
    fi    #
  else                                                   # create $YAML
    test "$debug" && echo
    test "$debug" && echo "mkdir -p $(dirname $YAML) 2>&1"
    mkdir -p $(dirname $YAML) 2>&1
    if test $? -ne 0
    then
      echo "** ERROR $me creating directory $(dirname $YAML) failed"
      echo "ls -ld \"$(dirname $YAML)\""; ls -ld "$(dirname $YAML)"
      rc=8
    fi    #

  	test -z "$rc" && _writeConfiguationFile $YAML
  fi    #
fi    #  create config

# Read config file
test -z "$rc" && _parseConfiguationFile $YAML

# If not set, set rc to 0
test -z "$rc" && rc=0

test "$debug" && echo "< $me $rc"
test "$LOG_FILE" && echo "</$me> $rc" >> $LOG_FILE
me=$saved_me
# No exit, shell sharing with caller
