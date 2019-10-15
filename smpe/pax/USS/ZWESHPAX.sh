#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2019, [YEAR]
#######################################################################

# Explode or remove exploded output of a SMP/E-mananaged pax file
# Zowe Open Source project
#
# SMP/E will set these environment variables for the script to use
#
#   SMP_File      - name of the SMP/E file that triggered the script
#                   invocation
#   SMP_Directory - directory in which the SMP/E file resides
#                   (with trailing /)
#   SMP_Action    - the action that SMP/E is performing: COPY or DELETE
#   SMP_Phase     - indicates if the shell script is called before or
#                   after SMP/E has processed the file: PRE or POST
#                   action=DELETE -> Phase=PRE (always)
#                   action=COPY   -> Phase=POST by default
#
# SMP/E expects a retun code
#
#   0             - all is OK
#   anything else - error, SMP/E processing will fail
#
# ---------------------------------------------------------------------
#
# Due to PTF size regulations, the data may be spread out over one or
# more pax files.
# Each pax file holds a manifest describing all the data, as we cannot
# control the order in which SMP/E processes the pax files.
# Cleanup work for all data mentioned in the manifest is done when the
# first pax file of a set is processed.
#
#
# -- PRE DELETE
#
# If the manifest exists in the filesystem, delete everything
# listed in the manifest and the manifest itself.
#
# -- PRE COPY
#
# no action
#
# -- POST COPY
#
# If the manifest exists in the filesystem, then do not delete.
# Otherwise, delete everything listed in the oldest manifest (which can
# be an existing or the new manifest) and the manifest itself.
# Explode pax after cleanup finished.
#
# ---------------------------------------------------------------------

manifest="manifest.txt"        # all manifest files share this filetype
pax_prefix="ZWEPAX"                   # all pax files share this prefix
IgNoRe_ErRoR=                  # if not null, then do not exit on error

# ---------------------------------------------------------------------
# --- show & execute command
#     stderr is routed to stdout to preserve the order of messages
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _cmd
{
if test "$1" = "-null"
then         # stdout -> null, stderr -> stdout (without going to null)
  shift
  echo $@ 2>&1 >/dev/null
       $@ 2>&1 >/dev/null
else         # stderr -> stdout, caller can add >/dev/null to trash all
  echo $@ 2>&1
       $@ 2>&1
fi    #
}    # _cmd


# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _cmdrc
{
if test "$1" = "-null"
then         # stdout -> null, stderr -> stdout (without going to null)
  shift
  echo $@ 2>&1 >/dev/null
       $@ 2>&1 >/dev/null
else         # stderr -> stdout, caller can add >/dev/null to trash all
  echo $@ 2>&1
       $@ 2>&1
fi    #
status=$?
if test $status -ne 0
then
  echo "** ERROR '$@' ended with status $status"
  echo "** Exiting script with status $status"
  echo
  test "$IgNoRe_ErRoR" || exit $status                           # EXIT
fi    #
}    # _cmdrc


# ---------------------------------------------------------------------
# --- delete files/directories listed in a manifest, optionally
#     also remove a manifest
# $1: manifest to use for cleanup
# $2: (optional) manifest to remove
# assumes we are in product home
# ---------------------------------------------------------------------
function _deleteFiles
{
#
# count all files & directories to be deleted
#
echo +- counting files
total=0
for F in $(sed '/^#/d' "$active")
do
  if test -e $F
  then
    counter=$(find $F | wc -l)
    echo +- $counter entries in $F
    let "total=$total + $counter"
  else
    echo +- skip counting $F, does not exist
  fi    #
done    # for F
echo -- Removing $total files and directories

#
# delete all files & directories listed in active manifest
#
for F in $(sed '/^#/d' "$active")
do
  if test -e $F
  then
    echo +- removing $F
    _cmdrc rm -r $F
  else
    echo +- skip removing $F, does not exist
  fi    #
done    # for F

#
# delete active manifest
#
echo +- removing $active
_cmdrc rm "$active"
}    # _deleteFiles


# ---------------------------------------------------------------------
# --- explode pax file, path relative to current dir
# ---------------------------------------------------------------------
function _addFiles
{
#
# validate the pax file by counting number of files within
#
_cmdrc eval total=$(pax -f "$pax_file" | wc -l | sed 's/ //g')
echo "-- Exploding $total entries"

#
# explode pax
# pax
#  -f "$pax_file"      pax file
#  -r                  read (extract)
#  -px                 process extended attributes
#  -v                  verbose
#
_cmdrc pax -f "$pax_file" -r -px -v

#
# restore symbolic links as instructed by the manifest
# sample input:
# #LNK ./jes_explorer/node_modules/.bin/which -> ../which/bin/which
#
echo +- restoring symbolic links
sed -n '/^#LNK/p' $manifest | while read -r junk1 file junk2 target
do
  if test -e "$file"
  then
    echo "+- skip creating $file, already exists"
  elif test -d "$(dirname $file)"
  then
    echo "+- creating $file -> $target"
    ln -s $target $file 2>&1
  else
    echo "+- skip creating $file, directory does not exist"
  fi    #
done    # while read

#
# count all files, directories & links currently present
# sample input:
# admin
#
echo +- counting files
total=0
for F in $(sed '/^#/d' "$manifest")    # pax manifest is now active one
do
  if test -e $F
  then
    counter=$(find $F | wc -l)
    echo +- $counter entries in $F
    let "total=$total + $counter"
  else
    echo +- skip counting $F, does not exist
  fi    #
done    # for F
echo +- $total files, directories and links currently present
}    # _addFiles


# ---------------------------------------------------------------------
# --- process phase PRE, action DELETE
#
# ->PRE  - DELETE           : removing existing pax, pax file exists
# - PRE  - COPY, GA install : pax file does not yet exist
# - PRE  - COPY, PTF install: previous version of pax file exists
# - POST - COPY, GA & PTF   : new version of pax file exists
#
# If the manifest exists in the filesystem, delete everything
# listed in the manifest and the manifest itself.
#
# (Data can be spread over multiple pax files, which will each go
#  through this step. By testing if the manifest exists in the
#  filesystem, we continue only if this is the first pax file of
#  the set.)
#
# assumes we are in product home
# ---------------------------------------------------------------------
function _preDelete
{
# (note: $manifest == $active)

##
## fail processing if manifest is a null string
## (= manifest not found in pax)
##
#_cmdrc test "$manifest"

if test ! "$manifest"
then
  #
  # warn but continue processing if manifest is a null string
  # (= manifest not found in pax)
  #
  echo "** WARNING $SMP_File does not have a manifest"
fi    #

#
# exit gracefully if manifest is no longer present in filesystem
# (= manifest already processed)
#
if test ! -f "$manifest"
then
  echo "** INFO the manifest no longer exists, action already done"
  echo "** Exiting script with status 0"
  exit 0                                                         # EXIT
fi    #

#
# delete all files & directories listed in manifest + manifest itself
#
_deleteFiles
}    # _preDelete


# ---------------------------------------------------------------------
# --- process phase PRE, action COPY
#
# - PRE  - DELETE           : removing existing pax, pax file exists
# ->PRE  - COPY, GA install : pax file does not yet exist
# ->PRE  - COPY, PTF install: previous version of pax file exists
# - POST - COPY, GA & PTF   : new version of pax file exists
#
# assumes we are in product home
# ---------------------------------------------------------------------
function _preCopy
{
echo "-- no processing for phase PRE action COPY"
}    # _preCopy


# ---------------------------------------------------------------------
# --- process phase POST, action COPY
#
# SMP/E just added/updated a pax file
# - pax file is of this sysmod
# - exploded files can be of previous sysmod or partial of this sysmod
#
# - PRE  - DELETE           : removing existing pax, pax file exists
# - PRE  - COPY, GA install : pax file does not yet exist
# - PRE  - COPY, PTF install: previous version of pax file exists
# ->POST - COPY, GA & PTF   : new version of pax file exists
#
# If the manifest exists in the filesystem, then do not delete.
# Otherwise, delete everything listed in the oldest manifest (which can
# be an existing or the new manifest) and the manifest itself.
# Explode pax after cleanup finished.
#
# (Data can be spread over multiple pax files, which will each go
#  through this step. By testing if the manifest exists in the
#  filesystem, we continue only if this is the first pax file of
#  the set.)
#
# if manifest == ''
# then (manifest == '')
#      (1) error
#          exit
# else (manifest <> '')
#   if active == ''
#   then (manifest <> '', active == '')
#        (2) GA & pax is first of set
#            optional cleanup of files (nothing to delete)
#            optional cleanup of active manifest (nothing to delete)
#            explode new pax
#   else (manifest <> '', active <> '')
#     if manifest == active
#     then (manifest <> '', active <> '', manifest == active)
#          (3) GA or PTF, pax is continuation of set
#              no cleanup of files
#              optional cleanup of active manifest (will be replaced)
#              explode new pax
#     else (manifest <> '', active <> '', manifest <> active)
#          (4) PTF, pax is first of set
#              cleanup of files required
#              cleanup of active manifest required
#              explode new pax
#
# assumes we are in product home
# ---------------------------------------------------------------------
function _postCopy
{
##
## (1) fail processing if manifest is a null string
## (= manifest not found in pax)
##
#_cmdrc test "$manifest"

if test ! "$manifest"
then
  #
  # (1) warn but continue proocessing if manifest is a null string
  # (= manifest not found in pax)
  #
  echo "+- manifest == '', active ?? ''"
  echo "** WARNING $SMP_File does not have a manifest, no cleanup done"

#
# (manifest <> '')
#
elif test ! "$active"
then
  #
  # (manifest <> '', active == '')
  #
  # (2) no removal if active manifest is a null string
  # (= GA & pax is first of a set)
  #
  echo "+- manifest <> '', active == ''"
  echo "-- No cleanup actions required"

#
# (manifest <> '', active <> '')
#
elif test "$manifest" = "$active"
then
  #
  # (manifest <> '', active <> '', manifest == active)
  #
  # (3) no removal if active manifest matches the new manifest
  # (= this pax is a continuation of a set)
  #
  echo "+- manifest <> '', active <> '', manifest == active"
  echo "-- No cleanup actions required"

else
  #
  # (manifest <> '', active <> '', manifest <> active)
  #
  # (4) remove active files if active and new manifest do not match
  # (= this pax is the first one of a PTF set)
  # Also remove the active manifest
  #
  echo "+- manifest <> '', active <> '', manifest <> active"
  echo "-- Removing files & manifest using active manifest"

  #
  # remove previous sysmod files
  #
  _deleteFiles
fi    #

#
# explode pax
#
_addFiles
}    # _postCopy


# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }
echo "-- Start script processing..."
status=0                       # script status, initial value must be 0

# enable detailed error messages
_EDC_ADD_ERRNO2=1

# display general statistics
echo
whence $0
echo $(sysvar SYSNAME) -- $(date) UTC
id
echo

echo "-- Input environment variables"
echo
echo "SMP_Directory=$SMP_Directory"
echo "SMP_File     =$SMP_File"
echo "SMP_Phase    =$SMP_Phase"
echo "SMP_Action   =$SMP_Action"
echo
echo "-- Processing $SMP_File $SMP_Phase $SMP_Action"
echo

#
# verify that the required input was received by the shell script
#
if test ! "$SMP_Directory"
then
  echo "** ERROR No SMP_Directory parameter specified."
  status=-1
elif test ! "$SMP_File"
then
  echo "** ERROR No SMP_File parameter specified."
  status=-1
elif test ! "$SMP_Phase"
then
  echo "** ERROR No SMP_Phase parameter specified."
  status=-1
elif test ! "$SMP_Action"
then
  echo "** ERROR No SMP_Action parameter specified."
  status=-1
fi    #
if test $status -ne 0       # if status is not 0, an error was detected
then
  echo " If SMP/E was not used to invoke the script, correct the"
  echo " caller to specify the input environment variables."
  echo " If SMP/E invoked this script, contact the IBM support center."
  echo "** Exiting script with status $status"
  echo
  test "$IgNoRe_ErRoR" || exit $status                           # EXIT
fi    #

#
# test whether we can write to $TMPDIR (required for shell pipes)
#
if test ! -w "${TMPDIR:-/tmp}"
then
  status=-1
  echo "** ERROR cannot write to ${TMPDIR:-/tmp}"
  echo "** Exiting script with status $status"
  echo
  test "$IgNoRe_ErRoR" || exit $status                           # EXIT
fi    #

#
# shorten the variable name
#
pax_file=${SMP_Directory}${SMP_File}

#
# go to the product home directory
# (expects that SMPE dir is one below home dir level)
#
_cmdrc cd ${SMP_Directory}..

#
# create wildcard mask that covers every manifest for this product
#
# sample: ZWEPAX.*.manifest.txt
#         assuming pax_prefix="ZWEPAX", manifest="manifest.txt"
#
mask="${pax_prefix}.*.${manifest}"

#
# get manifest name of active sysmod (GA or PTF)
# can be null, the same as in the pax, or an older one
#
active=$(ls $mask 2>/dev/null | tail -l 1)
echo -- Existing manifest: \"$active\"                               #"

#
# extract name of manifest inside pax file, if pax file exists
# - PRE  - DELETE           : removing existing pax, pax file exists
# - PRE  - COPY, GA install : pax file does not yet exist
# - PRE  - COPY, PTF install: previous version of pax file exists
# - POST - COPY, GA & PTF   : new version of pax file exists
# grep will filter line with exact match after expanding wildcard
#
unset manifest
if test -f "$pax_file"
then
  _cmdrc eval manifest=$(pax -f "$pax_file" | grep ^${mask}$)
fi    #
echo -- Manifest in pax: \"$manifest\"                               #"

#
# continue processing based upon SMP/E action (COPY/DELETE)
#
if test "SMP_Action" = "DELETE"
then  # DELETE action, PRE phase
  #
  # SMP/E is about to delete the pax file
  #
  _preDelete

else  # COPY action, PRE or POST phase
  #
  # continue processing based upon SMP/E phase (PRE/POST)
  #
  if test "$SMP_Phase" = "PRE"
  then  # PRE phase, COPY action
    #
    # SMP/E is about to add/update the pax file
    #
    _preCopy

  else  # POST phase, COPY action
    #
    # SMP/E added/updated the pax file
    #
    _postCopy

  fi    # POST phase
fi    # COPY action

echo
echo "-- Exiting script with status 0"
echo
exit 0
