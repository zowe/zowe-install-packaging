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

# TODO - ALTERS INSTALLED PRODUCT

# TODO is rename from zowe-install-iframe-plugin.sh acceptable?

# Add API Catalog application to zLUX.
# Called by zowe-configure-zlux.sh zowe-configure-explorer-ui.sh
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
# $IgNoRe_ErRoR $debug $LOG_FILE $ZOWE_ROOT_DIR
#
# NOTICE: This script will automatically create the install folder
#         based on the plugin name, $ZOWE_ROOT_DIR/$PLUGIN_FOLDER_NAME

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
echo "Usage: $me  ZOWE_ROOT_DIRECTORY  PLUGIN_ID  PLUGIN_SHORTNAME  URL  TILE_IMAGE_PATH" 1>&2
echo "e.g. $me  ~/zowe  org.zowe.plugin.example  \"Example plugin\"  https://zowe.org:443/about-us/   ~/zowe/myplugins/artifacts/tile_image.png" 1>&2
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
_cmd umask 0022                                  # similar to chmod 755

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

test -n "$rc" -a ! "$IgNoRe_ErRoR" && exit 8                     # EXIT

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Switch spaces to underscores and lower case it for use as folder name
PLUGIN_FOLDER_NAME=$(echo $PLUGIN_SHORTNAME \
  | tr -s ' ' | tr ' ' '_' | tr '[:upper:]' '[:lower:]') 2>&1
PLUGIN_FOLDER=$ZOWE_ROOT_DIR/$PLUGIN_FOLDER_NAME 2>&1

_cmd mkdir -p $PLUGIN_FOLDER/web/images

# Stage the tile image graphic
_cmd cp $TILE_IMAGE_PATH $PLUGIN_FOLDER/web/images/
# No original to save, but add customized one so restore can process it
_backup $PLUGIN_FOLDER/web/images/$(basename $TILE_IMAGE_PATH)

# Tag the graphic as binary
_cmd chtag -b $PLUGIN_FOLDER/web/images/$(basename $TILE_IMAGE_PATH)

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
test $? -ne 0 -a ! "$IgNoRe_ErRoR" && exit 8                     # EXIT
# No original to save, but add customized one so restore can process it
_backup $PLUGIN_FOLDER/web/index.html

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
test $? -ne 0 -a ! "$IgNoRe_ErRoR" && exit 8                     # EXIT
# No original to save, but add customized one so restore can process it
_backup $PLUGIN_FOLDER/pluginDefinition.json

test "$debug" && echo "cat <<EOF 2>&1 >$ZOWE_ROOT_DIR/$zluxserver/plugins/$PLUGIN_ID.json"
cat <<EOF 2>&1 >$ZOWE_ROOT_DIR/$zluxserver/plugins/$PLUGIN_ID.json
{
  "identifier": "$PLUGIN_ID",
  "pluginLocation": "../../$PLUGIN_FOLDER_NAME"
}
EOF
test $? -ne 0 -a ! "$IgNoRe_ErRoR" && exit 8                     # EXIT
# No original to save, but add customized one so restore can process it
_backup $ZOWE_ROOT_DIR/$zluxserver/plugins/$PLUGIN_ID.json

test "$debug" && echo "< $(basename $0) 0"
test "$LOG_FILE" && echo "</$me> 0" >> $LOG_FILE
exit 0
