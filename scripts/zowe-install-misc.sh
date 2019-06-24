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

# Install miscelaneous Zowe files.
# Called by zowe-install.sh
#
# Arguments:
#  adminDir  target directory for installed zowe.yaml 
#
# Expected globals:
# $ReMoVe $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR

list=""   # file/directory names include path based on $INSTALL_DIR
list="$list manifest.json"
list="$list files/assets/api-catalog.png"
list="$list licenses/zowe_licenses_full.zip"
list="$list scripts/"  # directory, must have trailing /
# Note: path to scripts directory MUST be identical for $INSTALL_DIR
#       and $ZOWE_ROOT_DIR, so that install, configuration and 
#       runtime can all utilize $ZOWE_SCRIPTS & $scripts.
#       KEEP IN SYNC WITH definition of $ZOWE_SCRIPTS in zowe-set-envvars.sh

here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- Miscelaneous"
test "$debug" && echo "> $me $@"
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

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

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

adminDir=$1

# Copy files keeping the same directory structure
for file in $list
do
  # directories are marked with / at the end
  if test "$(echo $file | grep /$)"
  then                                                      # directory
    file=${file%/}                                   # strip trailing /
    test "$debug" && echo "file=$file (directory)"
    _cmd $scripts/copy.sh \
      "$INSTALL_DIR/$file" \
      "$ZOWE_ROOT_DIR/$file" \
      "$(basename $file) directory"
  else                                                      # file
    test "$debug" && echo "file=$file (file)"
    _cmd $scripts/copy.sh \
      "$INSTALL_DIR/$file" \
      "$ZOWE_ROOT_DIR/$(dirname $file)" \
      "miscelaneous"
  fi    #
done    # for file

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

echo "  Copy of $ZOWE_CFG into $adminDir" >> $LOG_FILE

# Copy zowe.yaml configuration file to our admin directory
_cmd cp $ZOWE_CFG $adminDir/$(basename $ZOWE_CFG)
  
# Remove install source if requested, but only if it is our sample
test "$ReMoVe" -a "$ZOWE_CFG" = "$INSTALL_DIR/install/zowe.yaml" && \
  _cmd rm -f $INSTALL_DIR/install/zowe.yaml

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# TODO adjust zLUX to have deploy with the rest of Zowe scripts
# Create relative symlink scripts/zowe-configure-zlux-deploy.sh to zlux-build/deploy.sh
# logic: To get to the target, sed replaces each directory in
#        $ZOWE_SCRIPTS with .. which brings us to $ZOWE_ROOT_DIR
#        (without knowing $ZOWE_ROOT_DIR). To this we can append the
#        path to the target.
_cmd ln -s \
  "$(echo $ZOWE_SCRIPTS | sed 's![^/]*!..!g')/zlux-build/deploy.sh" \
  "$ZOWE_ROOT_DIR/$ZOWE_SCRIPTS/zowe-configure-zlux-deploy.sh"

# Remove install script if requested
test "$ReMoVe" && _cmd rm -f $0

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
exit 0
