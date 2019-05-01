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

# Install the Zowe zLUX server.
# Called by zowe-install.sh
#
# caller needs these RACF permits:
# TSO PE BPX.FILEATTR.PROGCTL CL(FACILITY) ACCESS(READ) ID(userid)
# TSO SETR RACLIST(FACILITY) REFRESH
#
# Arguments:
# /
#
# Expected globals:
# $ReMoVe $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR $ZOWE_ROOT_DIR

list=""
list="$list sample-angular-app.pax"
list="$list sample-iframe-app.pax"
list="$list sample-react-app.pax"
list="$list tn3270-ng2.pax"
list="$list vt-ng2.pax"
list="$list zlux-core.pax"
list="$list zlux-editor.pax"
list="$list zlux-workflow.pax"
list="$list zosmf-auth.pax"
list="$list zss-auth.pax"
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- zLUX"
test "$debug" && echo "> $me $@"
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

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
  echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _cmd

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing
_cmd umask 0022                                  # similar to chmod 755

# Set environment variables when not called via zowe-install.sh
if test -z "$INSTALL_DIR"
then
  # Set all required environment variables & logging
  # Note: script exports environment vars, so run in current shell
  _cmd . $(dirname $0)/../scripts/zowe-set-envvars.sh $0
else
  echo "  $(date)" >> $LOG_FILE
fi    #

# Extract archives (zlux-core.pax in root, others in sub-directory)
for file in $list
do
  plugin="${file%.*}"                                    # strip '.pax'
  unset dir
  test "$file" != "zlux-core.pax" && dir=$plugin

  _cmd $INSTALL_DIR/scripts/unpax.sh \
    "$INSTALL_DIR/files/zlux/$file" \
    "$ZOWE_ROOT_DIR/$dir" \
    "$plugin"
done    # for file

# Copy zss server front-end, extattr +p is lost
_cmd $INSTALL_DIR/scripts/copy.sh \
  "$INSTALL_DIR/files/zss/zssServer" \
  "$ZOWE_ROOT_DIR/zlux-app-server/bin/" \
  "zss server front-end"

# ---

# Prepare for additional tasks
config=$INSTALL_DIR/files/zlux/config
_cmd cd $ZOWE_ROOT_DIR

# Mark executable as program controlled
_cmd extattr +p zlux-app-server/bin/zssServer

# TODO why not in pax?
# Create log directory
# Requires new R/W file system when ZOWE_ROOT_DIR is mounted R/O
_cmd mkdir -p zlux-app-server/log

# TODO why not in pax?
# Create directory not part of plugin pax file
_cmd mkdir -p zlux-app-server/pluginDefaults/org.zowe.zlux.ng2desktop/ui/launchbar/plugins

# TODO move to configuration steps? If so move $config to ZOWE_ROOT_DIR
# Add default config files
_cmd cp -f $config/pinnedPlugins.json zlux-app-server/pluginDefaults/org.zowe.zlux.ng2desktop/ui/launchbar/plugins/
_cmd cp -f $config/zluxserver.json    zlux-app-server/config/
_cmd cp -f $config/plugins/*          zlux-app-server/plugins/      #*/

# Remove install source if requested
test "$ReMoVe" && _cmd rm -f $config/pinnedPlugins.json
test "$ReMoVe" && _cmd rm -f $config/zluxserver.json
test "$ReMoVe" && _cmd rm -f $config/plugins/*

# TODO if keep then move to configuration steps
# Open the permission so that a user other than the one who does the
# install can start the nodeServer and create logs
#_cmd chmod 777 zlux-app-server/log               
#_cmd chmod ug+w zlux-app-server/bin/zssServer

# Remove install script if requested
test "$ReMoVe" && _cmd rm -f $0

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
exit 0
