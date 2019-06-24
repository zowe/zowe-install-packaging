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

# TODO why is deploy.sh in zlux-core.pax (zlux-build/deploy.sh) instead of scripts?

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
# $ReMoVe $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR

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
here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- zLUX"
test "$debug" && echo "> $me $@"
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

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

TmP=$TMPDIR/$(basename $1)
_cmd --repl $TmP sed $SED $1                    # sed '...' $1 > $TmP
_cmd mv $TmP ${2:-$1}                           # give $TmP actual name
test -n "$ExEc" && _cmd chmod a+x ${2:-$1}      # make executable
}    # _sed

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

  _cmd $scripts/unpax.sh \
    "$INSTALL_DIR/files/zlux/$file" \
    "$ZOWE_ROOT_DIR/$dir" \
    "$plugin"
done    # for file

# Copy zss server front-end, extattr +p is lost (set again later)
_cmd $scripts/copy.sh \
  "$INSTALL_DIR/files/zss/zssServer" \
  "$ZOWE_ROOT_DIR/zlux-app-server/bin/" \
  "zss server front-end"

# ---

# Prepare for additional tasks
config=$INSTALL_DIR/files/zlux/config
app-server=$ZOWE_ROOT_DIR/zlux-app-server

# Mark executable as program controlled
_cmd extattr +p $app-server/bin/zssServer

# removed - nodeLogs in zowe.yaml set explicit log directory
# TODO why is this not in pax?
# TODO zlux-app-server/log requires new R/W file system when ZOWE_ROOT_DIR is mounted R/O
#_cmd mkdir -p $app-server/log

# TODO why is this not in pax?
_cmd mkdir -p $app-server/pluginDefaults/org.zowe.zlux.ng2desktop/ui/launchbar/plugins

# TODO why are these not in pax?
# Add default config files
echo "  Copy of $config/<...> into $app-server/<...>" >> $LOG_FILE
_cmd cp -f $config/pinnedPlugins.json $app-server/pluginDefaults/org.zowe.zlux.ng2desktop/ui/launchbar/plugins/
_cmd cp -f $config/plugins/*          $app-server/plugins/          #*/
# TODO why is there a missing line in zluxserver.json?
if grep -q gatewayPort "$config/zluxserver.json"
then  # copy as-is
  _cmd cp -f $config/zluxserver.json $app-server/config/
else  # add missing line
  _cmd --repl $app-server/config/zluxserver.json \
    awk -v line='        "gatewayPort": 10010,' \
    '/hostname/{printf("%s\n",line)} {print $0}' \
    $config/zluxserver.json
fi    #

# TODO zluxserver.json should ship with unique port markers
# Create unique port-markers in zluxserver.json
SED=""
SED="$SED;s/8544/%8544%/g"
SED="$SED;s/8542/%8542%/g"
SED="$SED;s/10010/%10010%/g"
_sed $ZOWE_ROOT_DIR/zlux-app-server/config/zluxserver.json

# Remove install source if requested
test "$ReMoVe" && _cmd rm -f $config/pinnedPlugins.json
test "$ReMoVe" && _cmd rm -f $config/zluxserver.json
test "$ReMoVe" && _cmd rm -f $config/plugins/*

# TODO if keep then move to configuration steps
# Open the permission so that a user other than the one who does the
# install can start the nodeServer and create logs
#_cmd chmod 777 $app-server/log
#_cmd chmod ug+w $app-server/bin/zssServer

# Remove install script if requested
test "$ReMoVe" && _cmd rm -f $0

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
exit 0
