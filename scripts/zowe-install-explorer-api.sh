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

# Install the Zowe Explorer API.
# Called by zowe-install.sh
#
# Arguments:
# /
#
# Expected globals:
# $ReMoVe $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR

here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- Explorer API"
test "$debug" && echo "> $me $@"
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

# ---------------------------------------------------------------------
# --- install API server code & startup script
# $1: API name
# $2: name of API port environment variable (see zowe-parse-yaml.sh)
# ---------------------------------------------------------------------
function _install
{
name=$1
portVar=$2

test "$debug" && echo "processing $name API"

# Target paths based on $ZOWE_ROOT_DIR
folder="explorer-${name}-api"
scriptFolder=$folder/scripts

# Update template startup script (in $INSTALL_DIR)
SED="s|\*\*SERVER_NAME\*\*|${name}|g"
SED="$SED;s|\*\*SERVER_PORT\*\*|${portVar}|g"
_sed -x $INSTALL_DIR/files/scripts/${name}-api-server-start.sh

# Install
_cmd $scripts/copy.sh \
  "$INSTALL_DIR/files/${name}-api-server-*.jar" \
  "$ZOWE_ROOT_DIR/$folder" \
  "$name explorer API"

_cmd $scripts/copy.sh \
  "$INSTALL_DIR/files/scripts/${name}-api-server-start.sh" \
  "$ZOWE_ROOT_DIR/$scriptFolder" \
  "$name explorer API"

# Create relative symlink $scriptFolder/zowe-scripts to $ZOWE_SCRIPTS
# logic: To get to the target, sed replaces each directory in
#        $scriptFolder with .. which brings us to $ZOWE_ROOT_DIR
#        (without knowing $ZOWE_ROOT_DIR). To this we can append the
#        path to the target.
_cmd ln -s \
  "$(echo $scriptFolder | sed 's![^/]*!..!g')/$ZOWE_SCRIPTS" \
  "$ZOWE_ROOT_DIR/$scriptFolder/zowe-scripts"
}    # _install

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

# Customize placeholders in server startup scripts & install
_install jobs      ZOWE_EXPLORER_SERVER_JOBS_PORT
_install data-sets ZOWE_EXPLORER_SERVER_DATASETS_PORT

# Remove install script if requested
test "$ReMoVe" && _cmd rm -f $0

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
exit 0
