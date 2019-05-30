#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# 5698-ZWE Copyright Contributors to the Zowe Project. 2018, 2019
#######################################################################

# TODO is rename from zowe-install-existing-plugin.sh acceptable?

# Add existing plugin to zLUX.
# Called by zowe-configure.sh
#
# Arguments:
# ZOWE_ROOT_DIR  Zowe root directory
# PLUGIN_ID      id of the plugin, e.g. "org.zowe.zlux.auth.apiml"
# PLUGIN_DIR     absolute path to the directory with the plugin
#
# Expected globals:
# $debug $LOG_FILE
#
# Return code:
# 0: plugin added
# 8: error

test "$debug" && echo "> $(basename $0) $@"
test "$LOG_FILE" && echo "<$(basename $0)> $@" >> $LOG_FILE

# ---------------------------------------------------------------------
# --- display script usage information
# ---------------------------------------------------------------------
function _displayUsage
{
echo "Usage: $(basename $0) ZOWE_ROOT_DIRECTORY  PLUGIN_ID  PLUGIN_DIRECTORY" >&2
echo "e.g. $(basename $0) ~/zowe  org.zowe.plugin.example  ~/zowe/myplugins" >&2
}    # _displayUsage

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

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

if test -z "$rc"                              # only if no error so far
then
  test "$debug" && echo "cat <<EOF 2>&1 >$zluxPlugin/$PLUGIN_ID.json"
  cat <<EOF 2>&1 >$zluxPlugin/$PLUGIN_ID.json
{
  "identifier": "$PLUGIN_ID",
  "pluginLocation": "$PLUGIN_DIR"
}
EOF
  test $? -ne 0 && rc=8
fi    #

# If not set, set rc to 0
test -z "$rc" && rc=0

test "$debug" && echo "< $(basename $0) $rc"
test "$LOG_FILE" && echo "</$(basename $0)> $rc" >> $LOG_FILE
exit $rc
