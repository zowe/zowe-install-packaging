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

# Configure Explorer UI plugins.
# Called by zowe-configure.sh
#
# Arguments:
# /
#
# Expected globals:
# $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR

list="jes mvs uss"             # plugins to process
here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- Explorer UI plugins"
test "$debug" && echo "> $me $@"
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

# ---------------------------------------------------------------------
# --- get plugin-specific data from Node
#     assumes to be in $ZOWE_ROOT_DIR/$pluginFolder
# $1: environment variable to hold value
# $2: Node key
# $3: Node description
# ---------------------------------------------------------------------
function _prime
{
test "$debug" && echo "set $1"
TmP=$($node -e \
  "process.stdout.write(require('./package.json').config.$2)") 2>&1
sTaTuS=$?

if test $sTaTuS -ne 0
then
  echo "** ERROR $me invoking node for $3 failed with RC $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

if test -z $TmP
then
  echo "** ERROR $me cannot read $3" | tee -a $LOG_FILE
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

_cmd eval $1=$TmP
}    # _prime

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

# Set environment variables when not called via zowe-configure.sh
if test -z "$INSTALL_DIR"
then
  # Note: script exports environment vars, so run in current shell
  _cmd . $(dirname $0)/../scripts/zowe-set-envvars.sh $0
else
  echo "  $(date)" >> $LOG_FILE
fi    #

# Verify that Node is available
if test ! -d "$NODE_HOME"
then
  echo "** ERROR $me NODE_HOME specified in $ZOWE_CFG is not valid" \
    | tee -a $LOG_FILE
  echo "ls -ld \"$NODE_HOME\""; ls -ld "$NODE_HOME"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

node="$NODE_HOME/bin/node"
if test ! -x $node
then
  echo "** ERROR $me cannot execute '$node'" | tee -a $LOG_FILE
  echo "ls -ld \"$node\""; ls -ld "$node"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Define certificates from apiml keystore
unset suffix
test $(uname) = "OS/390" && suffix="-ebcdic"
keystorePath="$ZOWE_ROOT_DIR/api-mediation/keystore"
keystoreKey="$keystorePath/localhost/localhost.keystore.key"
keystoreCert="$keystorePath/localhost/localhost.keystore.cer${suffix}"

for plugin in $list
do
  test "$debug" && echo "plugin=$plugin"

  PLUGIN=$(echo $plugin | tr '[:lower:]' '[:upper:]')       # uppercase
  echo "  Configuring $PLUGIN Explorer UI" >> $LOG_FILE

  pluginPort="ZOWE_EXPLORER_${PLUGIN}_UI_PORT" 2>&1  # name of variable
  _cmd eval pluginPort='$'$pluginPort               # value of variable

  pluginFolder="$plugin_explorer"
  _cmd cd "$ZOWE_ROOT_DIR/$pluginFolder"

  _prime pluginBaseURI baseuri "server base uri"
  _prime pluginId pluginId "plugin ID"
  _prime pluginName pluginName "plugin name"

  echo "    - plugin ID   : $pluginID" >> $LOG_FILE
  echo "    - plugin name : $pluginName" >> $LOG_FILE
  echo "    - port        : $pluginPort" >> $LOG_FILE
  echo "    - base uri    : $pluginBaseURI" >> $LOG_FILE

  # Update default config.json
  # - replace URL
  # - replace port
  # - replace certificates
  SED="s|\"frame-ancestors\": *\[\$|\"frame-ancestors\": [\"https://${ZOWE_EXPLORER_HOST}:*\"|g" \
  SED="$SED;s|\"port\":.\+,|\"port\": ${pluginPort},|g"
  SED="$SED;s|\"port\":[^,]\+|\"port\": ${pluginPort}|g"
  SED="$SED;s|\"key\":[^,]\+,|\"key\": \"${keystoreKey}\",|g"
  SED="$SED;s|\"key\":[^,]\+|\"key\": \"${keystoreKey}\"|g"
  SED="$SED;s|\"cert\":[^,]\+,|\"cert\": \"${keystoreCert}\",|g"
  SED="$SED;s|\"cert\":[^,]\+|\"cert\": \"${keystoreCert}\"|g"
  _backup $ZOWE_ROOT_DIR/$pluginFolder/server/configs/config.json
  _sed $ZOWE_ROOT_DIR/$pluginFolder/server/configs/config.json

  # Add explorer plugin to zLUX
  pluginImage="$ZOWE_ROOT_DIR/$pluginFolder/plugin-definition/zlux/images/explorer-${PLUGIN}.png"
  pluginURL="https://$ZOWE_EXPLORER_HOST:$ZOWE_APIM_GATEWAY_PORT$pluginBaseURI"
  _cmd $scripts/zowe-configure-zlux-add-iframe-plugin.sh \
    "$ZOWE_ROOT_DIR" \
    "$pluginID" \
    "$pluginName" \
    "$pluginURL" \
    "$pluginImage"

  echo "  $PLUGIN Explorer UI configured." >> $LOG_FILE
done    # for plugin

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
exit 0

