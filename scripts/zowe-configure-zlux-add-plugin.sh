#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2018, 2019
#######################################################################

# TODO is rename from zowe-install-existing-plugin.sh acceptable?

# Add existing plugin to zLUX.
# Called by zowe-configure-zlux.sh
#
# Arguments:
# ZOWE_ROOT_DIR  Zowe root directory
# PLUGIN_ID      id of the plugin, e.g. "org.zowe.zlux.auth.apiml"
# PLUGIN_DIR     absolute path to the directory with the plugin
#
# Expected globals:
# $IgNoRe_ErRoR $debug $LOG_FILE $ZOWE_ROOT_DIR

here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo "> $me $@"
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

# ---------------------------------------------------------------------
# --- display script usage information
# ---------------------------------------------------------------------
function _displayUsage
{
echo "** ERROR $me"
echo "Usage: $me  ZOWE_ROOT_DIRECTORY  PLUGIN_ID  PLUGIN_DIRECTORY" >&2
echo "e.g. $me  ~/zowe  org.zowe.plugin.example  ~/zowe/myplugins" >&2
}    # _displayUsage

# ---------------------------------------------------------------------
# --- Create backup of file, will be restored on all future config runs
# 1: absolute path to file that requires backup
# ---------------------------------------------------------------------
function _backup
{
if test -f "$ZOWE_ROOT_DIR/backup/restart-incomplete" 
then
  # create path that matches original path with backup/restart/ inserted
  # ${1#*$ZOWE_ROOT_DIR/}       # keep everything after $ZOWE_ROOT_DIR/
  _cmd mkdir -p $ZOWE_ROOT_DIR/backup/restart/$(dirname ${1#*$ZOWE_ROOT_DIR/})
  # copy file in newly created path
  _cmd cp -f $1 $ZOWE_ROOT_DIR/backup/restart/${1#*$ZOWE_ROOT_DIR/}
fi    #
}    # _backup

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
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing

# Ensure the rc variable is null
unset rc

# Get startup arguments
ZOWE_ROOT_DIR=$1
PLUGIN_ID=$2
PLUGIN_DIR=$3

zluxServer="zlux-app-server"
zluxPlugin="$ZOWE_ROOT_DIR/$zluxserver/plugins"

# Input validation, do not use elif so all tests run
if test "$#" -ne 3
then
  _displayUsage
  rc=8
fi    #

if test ! -d "$3"
then
  _displayUsage
  echo "PLUGIN_DIRECTORY $3 not a directory" >&2
  rc=8
fi    #

if test ! -d "$1"
then
  _displayUsage
  echo "ZOWE_ROOT_DIRECTORY $1 not a directory" >&2
  rc=8
elif test ! -w $zluxPlugin
#  chmod -R u+w $zluxPlugin
#  if test $? -ne 0
    _displayUsage
    echo "cannot write to $zluxPlugin" >&2
    rc=8
#  fi    #
fi    #

test -n "$rc" -a ! "$IgNoRe_ErRoR" && exit 8                     # EXIT

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

test "$debug" && echo "cat <<EOF 2>&1 >$zluxPlugin/$PLUGIN_ID.json"
cat <<EOF 2>&1 >$zluxPlugin/$PLUGIN_ID.json
{
  "identifier": "$PLUGIN_ID",
  "pluginLocation": "$PLUGIN_DIR"
}
EOF
test $? -ne 0 -a ! "$IgNoRe_ErRoR" && exit 8                     # EXIT
# No original to save, but add customized one so restore can process it
_backup $zluxPlugin/$PLUGIN_ID.json

test "$debug" && echo "< $me 0"
test "$LOG_FILE" && echo "</$me> 0" >> $LOG_FILE
exit 0
