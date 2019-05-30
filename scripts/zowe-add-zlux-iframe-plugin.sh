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

# TODO is rename from zowe-install-iframe-plugin.sh acceptable?

# Add API Catalog application to zLUX.
# Called by zowe-configure.sh
#
# Arguments:
# ZOWE_ROOT_DIR     Zowe root directory
# PLUGIN_ID         ID of the plugin, e.g. "org.zowe.explorer-jes"
# PLUGIN_SHORTNAME  short name of the plugin, e.g. "JES Explorer"
# URL               the full URL of the page being embedded
# TILE_IMAGE_PATH   full path link to the file location of the image 
#                   to be used as the mvd tile
#
# Expected globals:
# $ignore_error $debug $LOG_FILE
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
echo "Usage: $(basename $0)  ZOWE_ROOT_DIRECTORY  PLUGIN_ID  PLUGIN_SHORTNAME  URL  TILE_IMAGE_PATH" >&2
echo "e.g. $(basename $0) ~/zowe  org.zowe.plugin.example  \"Example plugin\"  https://zowe.org:443/about-us/   ~/zowe/myplugins/artifacts/tile_image.png" >&2
}    # _displayUsage

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $2: if $1 = --save then target receiving stdout
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
then         # stdout -> $2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 >> $sAvE"
                         $@ 2>&1 >> $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "$@ 2>&1"
                         $@ 2>&1
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** ERROR '$@' ended with status $sTaTuS"
  test ! "$ignore_error" && exit 1                               # EXIT
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
PLUGIN_SHORTNAME=$3
URL=$4
TILE_IMAGE_PATH=$5

zluxServer="zlux-app-server"
zluxPlugin="$ZOWE_ROOT_DIR/$zluxserver/plugins"

# Input validation, do not use elif so all tests run
if test "$#" -ne 5
then
  _displayUsage
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

if test ! -f "$5"
then
  _displayUsage
  echo "TILE_IMAGE_PATH $5 is not a file" >&2
  rc=8
fi

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

if test -z "$rc"                              # only if no error so far
then
  # Switch spaces to underscores and lower case it for use as folder name
  PLUGIN_FOLDER_NAME=$(echo $PLUGIN_SHORTNAME | tr -s ' ' | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
  PLUGIN_FOLDER=$ZOWE_ROOT_DIR/$PLUGIN_FOLDER_NAME

  _cmd mkdir -p $PLUGIN_FOLDER/web/images 

  # Stage the tile image graphic
  _cmd cp $TILE_IMAGE_PATH $PLUGIN_FOLDER/web/images/ 

  # Tag the graphic as binary
  _cmd chtag -b $PLUGIN_FOLDER/web/images/$(basename $TILE_IMAGE_PATH)
fi    #

if test -z "$rc"                              # only if no error so far
then
  test "$debug" && echo "cat <<EOF 2>&1 >$PLUGIN_FOLDER/web/index.html"
  cat <<EOF 2>&1 >$PLUGIN_FOLDER/web/index.html
<!DOCTYPE html>
<html>
  <body>
    <iframe 
      id="zluxIframe"
      src="$URL"; 
      style="position:fixed; top:0px; left:0px; bottom:0px; right:0px; width:100%; height:100%; border:none; margin:0; padding:0; overflow:hidden; z-index:999999;">
      Your browser does not support iframes
    </iframe>
  </body>
</html>
EOF
  test $? -ne 0 && rc=8
fi    #

if test -z "$rc"                              # only if no error so far
then
  test "$debug" && echo "cat <<EOF 2>&1 >$PLUGIN_FOLDER/pluginDefinition.json"
  cat <<EOF 2>&1 >$PLUGIN_FOLDER/pluginDefinition.json
{
  "identifier": "$PLUGIN_ID",
  "apiVersion": "1.0.0",
  "pluginVersion": "1.0.0",
  "pluginType": "application",
  "webContent": {
    "framework": "iframe",
    "startingPage": "index.html",
    "launchDefinition": {
      "pluginShortNameKey": "$PLUGIN_SHORTNAME",
      "pluginShortNameDefault": "$PLUGIN_SHORTNAME", 
      "imageSrc": "images/$(basename $TILE_IMAGE_PATH)"
    },
    "descriptionKey": "",
    "descriptionDefault": "",
    "isSingleWindowApp": true,
    "defaultWindowStyle": {
      "width": 1400,
      "height": 800
    }
  }
}
EOF
  test $? -ne 0 && rc=8
fi    #

if test -z "$rc"                              # only if no error so far
then
  test "$debug" && echo "cat <<EOF 2>&1 >$ZOWE_ROOT_DIR/$zluxserver/plugins/$PLUGIN_ID.json"
  cat <<EOF 2>&1 >$ZOWE_ROOT_DIR/$zluxserver/plugins/$PLUGIN_ID.json
{
  "identifier": "$PLUGIN_ID",
  "pluginLocation": "../../$PLUGIN_FOLDER_NAME"
}
EOF
  test $? -ne 0 && rc=8
fi    #

# If not set, set rc to 0
test -z "$rc" && rc=0

test "$debug" && echo "< $(basename $0) $rc"
test "$LOG_FILE" && echo "</$(basename $0)> $rc" >> $LOG_FILE
exit $rc
