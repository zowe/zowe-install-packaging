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

# Install administrator scripts.
# Called by zowe-install.sh
#
# Arguments:
# /
#
# Expected globals:
# $ReMoVe $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR

here=$(cd $(dirname $0);pwd)   # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- administrator scripts"
test "$debug" && echo "> $me $@"
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

# ---------------------------------------------------------------------
# --- copy file
# $1: source
# $2: target
# ---------------------------------------------------------------------
function _cp
{
_cmd cp -f "$1" "$2"
# Remove install source if requested
test "$ReMoVe" && _cmd rm -f "$1"
}    # _cp

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

dirLicenses=$ZOWE_ROOT_DIR/licenses
dirScripts=$ZOWE_ROOT_DIR/scripts
dirTemplates=$ZOWE_ROOT_DIR/scripts/templates
dirInternal=$ZOWE_ROOT_DIR/scripts/internal
dirConfigure=$ZOWE_ROOT_DIR/scripts/configure
dirUtils=$ZOWE_ROOT_DIR/scripts/utils

echo "  Copy files into $ZOWE_ROOT_DIR" >> $LOG_FILE
_cp $INSTALL_DIR/manifest.json $ZOWE_ROOT_DIR/

echo "  Copy files into $dirLicenses" >> $LOG_FILE
_cmd mkdir -p $dirLicenses
_cp $INSTALL_DIR/licenses/zowe_licenses_full.zip $dirLicenses/

echo "  Copy files into $dirScripts" >> $LOG_FILE
_cmd mkdir -p $dirScripts
_cp $INSTALL_DIR/scripts/allocate-dataset.sh    $dirScripts/
_cp $INSTALL_DIR/scripts/check-dataset-dcb.sh   $dirScripts/
_cp $INSTALL_DIR/scripts/check-dataset-exist.sh $dirScripts/
_cp $INSTALL_DIR/scripts/zowe-set-envvars.sh    $dirScripts/
_cp $INSTALL_DIR/scripts/zowe-verify.sh         $dirScripts/

echo "  Copy files into $dirTemplates" >> $LOG_FILE
_cmd mkdir -p $dirTemplates
_cp $INSTALL_DIR/scripts/zowe-start.template.sh          $dirTemplates/
_cp $INSTALL_DIR/scripts/zowe-stop.template.sh           $dirTemplates/
_cp $INSTALL_DIR/scripts/zowe-support.template.sh        $dirTemplates/
_cp $INSTALL_DIR/scripts/run-zowe.template.sh            $dirTemplates/
# TODO  remove afte adjusting customize - covered by zip #519
_cp $INSTALL_DIR/files/templates/ZOWESVR.template.jcl    $dirTemplates/
_cp $INSTALL_DIR/scripts/zowe-runtime-authorize.template.sh $dirTemplates/

echo "  Copy files into $dirInternal" >> $LOG_FILE
_cmd mkdir -p $dirInternal
_cp $INSTALL_DIR/scripts/opercmd        $dirInternal/
_cp $INSTALL_DIR/scripts/ocopyshr.sh    $dirInternal/
_cp $INSTALL_DIR/scripts/ocopyshr.clist $dirInternal/

echo "  Copy files into $dirConfigure" >> $LOG_FILE
_cmd mkdir -p $dirConfigure
_cp $INSTALL_DIR/install/zowe.yaml          $dirConfigure/
_cp $INSTALL_DIR/scripts/zowe-init.sh       $dirConfigure/
_cp $INSTALL_DIR/scripts/zowe-parse-yaml.sh $dirConfigure/
_cp "$INSTALL_DIR/scripts/configure/*"      $dirConfigure/

echo "  Copy files into $dirUtils" >> $LOG_FILE
_cmd mkdir -p $dirUtils
_cp "$INSTALL_DIR/scripts/utils/*" $dirUtils/

if test "$ReMoVe"
then
  echo "  Remove install specific files" >> $LOG_FILE
  # do NOT add $0 to this list, processed later
  obsolete=" \
    $INSTALL_DIR/install/zowe-check-prereqs.sh \
    $INSTALL_DIR/install/zowe-upgrade.sh \
    $INSTALL_DIR/scripts/copy.sh \
    $INSTALL_DIR/scripts/unpax.sh \
    "
  _cmd rm -Rf $obsolete
fi    #

# Remove install script if requested
test "$ReMoVe" && _cmd rm -f $0

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
exit 0
