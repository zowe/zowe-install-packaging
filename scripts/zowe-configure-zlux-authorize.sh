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

# Configure zLUX file access authorizations.
# Called by zowe-configure-zlux.sh
#
# Arguments:
# /
#
# Expected globals:
# $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR
#
# caller needs these RACF permits when install is done by another ID:
# TSO PE SUPERUSER.FILESYS.CHANGEPERMS CL(UNIXPRIV) ACCESS(READ) ID(userid)
# TSO PE SUPERUSER.FILESYS.CHOWN CL(UNIXPRIV) ACCESS(READ) ID(userid)

here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- zLUX authorizations"
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

# Set environment variables when not called via zowe-configure.sh
if test -z "$INSTALL_DIR"
then
  # Note: script exports environment vars, so run in current shell
  _cmd . $(dirname $0)/../scripts/zowe-set-envvars.sh $0
else
  echo "  $(date)" >> $LOG_FILE
fi    #

app-server=$ZOWE_ROOT_DIR/zlux-app-server

# Allow zLUX server (Zowe started task userid) select write access
# Assumes Zowe STC is a member of the Zowe administrator group
# other option is to give Zowe STC CONTROL to UNIXPRIV SUPERUSER.FILESYS
cmd="chgrp -h -R $ZOWE_ADMIN_GROUP $app-server/deploy/"
test "$debug" && echo
test "$debug" && echo "$cmd"
$cmd 2>/dev/null
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** WARNING $me '$cmd' ended with status $sTaTuS" \
    | tee -a $LOG_FILE
  echo "   It is uncertain whether the Zowe server has the required \
     access rights" | tee -a $LOG_FILE
  if test $sTaTuS -eq 1               # caller not authorized for chgrp
  then
    #
  else                          # $ZOWE_ADMIN_GROUP does not have a GID
    #
  fi    #
fi    # chgrp failure

# Only allow owner & Zowe admin group access to $app-server/deploy/
# Allow Zowe started task to write persistent data
_cmd chmod -h -R 770 $app-server/deploy/
# Product directory is controlled by Zowe install, only allow R-X
# Note: leave write for owner so the config script can be rerun
_cmd chmod -h -R g-w $app-server/deploy/product/
# Zowe server only needs read to serverConfig, but admin might need write
#_cmd chmod -h -R g-w $app-server/deploy/site/ZLUX/serverConfig/
#_cmd chmod -h -R g-w $app-server/deploy/instance/ZLUX/serverConfig/

# removed - nodeLogs in zowe.yaml set explicit log directory
## Allow all to create log files (required to start Node server)
#_cmd chmod 777 $app-server/log

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
exit 0
