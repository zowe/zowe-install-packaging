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

# Configure zLUX.
# Called by zowe-configure.sh
#
# Arguments:
# /
#
# Expected globals:
# $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR

here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- zLUX"
test "$debug" && echo "> $me $@"
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

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

unset suffix
test $(uname) = "OS/390" && suffix="-ebcdic"
keystorePath="$ZOWE_ROOT_DIR/api-mediation/keystore"
keystoreKey="$keystorePath/localhost/localhost.keystore.key"
keystoreCert="$keystorePath/localhost/localhost.keystore.cer${suffix}"
keystoreCA="$keystorePath/local_ca/localca.cer${suffix}"

# zLUX server
echo "  Updating zlux-app-server/config/zluxserver.json" >> $LOG_FILE
SED=""
SED="$SED;s/%8544%/$ZOWE_ZLUX_SERVER_HTTPS_PORT/g"
SED="$SED;s/%8542%/$ZOWE_ZSS_SERVER_PORT/g"
SED="$SED;s/%10010%/$ZOWE_APIM_GATEWAY_PORT/g"
SED="$SED;/hostname/s/localhost/$ZOWE_EXPLORER_HOST/"
SED="$SED;s|.*\"keys\".*|      \"keys\": [\"$keystoreKey\"],|g"
SED="$SED;s|.*\"certificates\".*|      \"certificates\": [\"$keystoreCert\"],|g"
SED="$SED;s|.*\"certificateAuthorities\".*|      \"certificateAuthorities\": [\"$keystoreCA\"]|g"
_backup $ZOWE_ROOT_DIR/zlux-app-server/config/zluxserver.json
_sed $ZOWE_ROOT_DIR/zlux-app-server/config/zluxserver.json

# SSH port for the VT terminal app
echo "  Updating vt-ng2/_defaultVT.json" >> $LOG_FILE
SED="s/22/$ZOWE_ZLUX_SSH_PORT/g"
_backup $ZOWE_ROOT_DIR/vt-ng2/_defaultVT.json
_sed $ZOWE_ROOT_DIR/vt-ng2/_defaultVT.json

# Telnet port & security type for the 3270 emulator app
echo "  Updating tn3270-ng2/_defaultTN3270.json" >> $LOG_FILE
SED="s/23/$ZOWE_ZLUX_TELNET_PORT/g"
test "$ZOWE_ZLUX_SECURITY_TYPE" = "tls" && \
  SED="$SED;s/telnet/$ZOWE_ZLUX_SECURITY_TYPE/g"
_backup $ZOWE_ROOT_DIR/tn3270-ng2/_defaultTN3270.json
_sed $ZOWE_ROOT_DIR/tn3270-ng2/_defaultTN3270.json

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Configure access to API Catalog
echo "  Configure access to API Catalog" >> $LOG_FILE
if test "$ZOWE_APIM_ENABLE_SSO" != "true"
then                                      # Access API Catalog directly
  test "$debug" && echo "access API Catalog directly"
  CATALOG_GATEWAY_URL="https://$ZOWE_EXPLORER_HOST:$ZOWE_APIM_GATEWAY_PORT/ui/v1/apicatalog/"
else                           # Access API Catalog with token injector
  test "$debug" && echo "access API Catalog with token injector"
  CATALOG_GATEWAY_URL="https://$ZOWE_EXPLORER_HOST:$ZOWE_ZLUX_SERVER_HTTPS_PORT/ZLUX/plugins/org.zowe.zlux.auth.apiml/services/tokenInjector/1.0.0/ui/v1/apicatalog/"

  # Add API Mediation Layer authentication plugin to zLUX
  _cmd $scripts/zowe-configure-zlux-add-plugin.sh \
     $ZOWE_ROOT_DIR \
     "org.zowe.zlux.auth.apiml" \
     $ZOWE_ROOT_DIR/api-mediation/apiml-auth

  # Define the plugin to zLUX
  SED='"apiml": { "plugins": ["org.zowe.zlux.auth.apiml"] }'
  SED='s/"zss": {/'"$SED"', "zss": {/g'
  _backup $ZOWE_ROOT_DIR/zlux-app-server/config/zluxserver.json
  _sed $ZOWE_ROOT_DIR/zlux-app-server/config/zluxserver.json
fi    # Configure access to API Catalog

# Add API Catalog application to zLUX
# required before we issue zLUX deploy.sh
_cmd $scripts/zowe-configure-zlux-add-iframe-plugin.sh \
  $ZOWE_ROOT_DIR \
  "org.zowe.api.catalog" \
  "API Catalog" \
  $CATALOG_GATEWAY_URL \
  $ZOWE_ROOT_DIR/files/assets/api-catalog.png

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Run deploy on the zLUX app server to propagate the changes made
silent="-s"
test "$debug" && unset silent
_cmd $scripts/zowe-configure-zlux-deploy.sh $silent

# Adjust zLUX access permisions, must run after deploy
_cmd $scripts/zowe-configure-zlux-authorize.sh

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
exit 0
