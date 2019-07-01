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

# Configure API Mediation certificates.
# Called by zowe-configure-api-mediation.sh
#
# Arguments:
# /
#
# Expected globals:
# $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR

# Variables to be populated when invoked outside of Zowe:
# JAVA_HOME                     - The base directory in which Java is installed
# ZOWE_ROOT_DIR                 - The base directory in which API Mediation is installed
# ZOWE_IPADDRESS                - The IP Address of the system running API Mediation
# ZOWE_EXPLORER_HOST            - The hostname of the system running API Mediation (defaults to localhost)
# ZOWE_ZOSMF_USERID             - z/OSMF server user ID
# ZOWE_ZOSMF_KEYRING            - Name of the z/OSMF keyring
# ZOWE_APIM_VERIFY_CERTIFICATES - true/false - Validation of TLS/SSL certitificates for services
# ZOWE_APIM_EXTERNAL_CERTIFICATE             - optional - Path to a PKCS12 keystore with a server certificate for APIM
# ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS       - optional - Alias of the certificate in the keystore
# ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES - optional - Public certificates of trusted CAs

here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- API Mediation certificates"
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

# Is this a Zowe install ?
if test -x "$(dirname $0)/../scripts/zowe-set-envvars.sh"
then                                               # YES, auto-populate
  # Set environment variables when not called via zowe-run.sh
  if test -z "$INSTALL_DIR"
  then
    # Note: script exports environment vars, so run in current shell
    _cmd . $(dirname $0)/../scripts/zowe-set-envvars.sh $0
  fi    #
else                                           # NO, manual definitions
  export JAVA_HOME=
  export ZOWE_ROOT_DIR=$here/../..
  export ZOWE_IPADDRESS=
  export ZOWE_EXPLORER_HOST=
  # if ZOWE_APIM_VERIFY_CERTIFICATES is true then ZOWE_ZOSMF_* must be set
  export ZOWE_ZOSMF_USERID=
  export ZOWE_ZOSMF_KEYRING=
  export ZOWE_APIM_VERIFY_CERTIFICATES=
  # Either all or no ZOWE_APIM_EXTERNAL_CERTIFICATE* variables must be set
  export ZOWE_APIM_EXTERNAL_CERTIFICATE=
  export ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS=
  export ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES=
fi    # manual variable definitions

# Prefix PATH with our Java location to ensure we invoke the right one
_cmd export PATH=$JAVA_HOME/bin:$PATH
test "$debug" && echo "PATH=$PATH"

# TODO clean up apiml_cm.sh so TEMP_DIR is no longer required
export TEMP_DIR=${TMPDIR:-/tmp}

# TODO clean up apiml_cm.sh so we can pass in keystore path
_cmd cd $ZOWE_ROOT_DIR/api-mediation

# Create keystore directory structure
keystorePath=$ZOWE_ROOT_DIR/api-mediation/keystore
_cmd mkdir -p $keystorePath/local_ca
_cmd mkdir -p $keystorePath/localhost

# TODO rename & rework apiml_cm.sh script

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Certificate generation

# Set apiml_cm.sh options
unset options
test "$debug" && options="$options --verbose"
test "$LOG_FILE" && options="$options --log $LOG_FILE"
if   test -z "$ZOWE_APIM_EXTERNAL_CERTIFICATE" \
  && test -z "$ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS" \
  && test -z "$ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES"
then                    # no variables have data -> create from scratch
  test "$debug" && echo "create from scratch"
  test "$LOG_FILE" && echo "  create from scratch" >> $LOG_FILE

  # no update to $options
elif test -n "$ZOWE_APIM_EXTERNAL_CERTIFICATE" \
  && test -n "$ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS" \
  && test -n "$ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES"
then             # all variables have data -> use external setup method
  test "$debug" && echo "using external setup"
  test "$LOG_FILE" && echo "  using external setup" >> $LOG_FILE

  options="$options --external-certificate $ZOWE_APIM_EXTERNAL_CERTIFICATE"
  options="$options --external-certificate-alias $ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS"

  for CA in $ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES
  do
    options="$options --external-ca $CA"
  done    # for CA
else                    # some but not all variables have data -> error
  echo "** ERROR $me incomplete externalCertificate* setup"
  echo "either all or no externalCertificate* variables must be set"
  echo "externalCertificate='$ZOWE_APIM_EXTERNAL_CERTIFICATE'"
  echo "externalCertificateAlias='$ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS'"
  echo "externalCertificateAuthorities='$ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES'"
  test ! "$IgNoRe_ErRoR" && exit 8                        # EXIT
fi    #

# TODO add IPv6 support to Subject Alternate Name (SAN)
SAN="SAN=dns:${ZOWE_EXPLORER_HOST}"
SAN="$SAN,ip:${ZOWE_IPADDRESS}"
SAN="$SAN,dns:localhost.localdomain"
SAN="$SAN,dns:localhost"
SAN="$SAN,ip:127.0.0.1"

# Invoke apiml_cm.sh
_cmd $here/../api-mediation/scripts/apiml_cm.sh \
  --action setup \
  --service-ext $SAN \
  $options  

# No original to save, but add customized one so restore can process it
for file in $(find $keystorePath -type f)
do
  _backup $file
done    # for file

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Trust z/OSMF
if [[ "${ZOWE_APIM_VERIFY_CERTIFICATES}" == "true" ]]
then
  # Set apiml_cm.sh options
  unset options
  test "$debug" && options="$options --verbose"
  test "$LOG_FILE" && options="$options --log $LOG_FILE"
  if   test -n "$ZOWE_ZOSMF_USERID" \
    && test -n "$ZOWE_ZOSMF_KEYRING"
  then                                # all variables have data -> good
    options="$options --zosmf-userid $ZOWE_ZOSMF_USERID"
    options="$options --zosmf-keyring $ZOWE_ZOSMF_KEYRING"
  else                           # not all variables have data -> error
    echo "** ERROR $me incomplete zosmf* setup"
    echo "all zosmf* variables must be set"
    echo "zosmfUser='$ZOWE_ZOSMF_USERID'"
    echo "zosmfKeyring='$ZOWE_ZOSMF_KEYRING'"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #

  # Invoke apiml_cm.sh (do not use _cmd wo we can test return code)
  cmd="$here/../api-mediation/scripts/apiml_cm.sh --action trust-zosmf"
  test "$debug" && echo
  test "$debug" && echo "$cmd $options 2>&1"
  $cmd $options 2>&1

  if test $? -ne 0
  then                                                        # failure
    echo "** WARNING $me '$cmd $options' failed"
    test "$LOG_FILE" && echo "** WARNING $me '$cmd $options' failed" \
      >> $LOG_FILE
    echo "WARNING: z/OSMF is not trusted by the API Mediation Layer. \
      Follow the 'Trust a z/OSMF certificate' instructions in the Zowe \
      documentation for manual repeat of the failed command."
  fi    #
fi    # trust-zosmf

# No need for _backup(), this step does not add files

test "$debug" && echo "< $me 0"
test "$LOG_FILE" && echo "</$me> 0" >> $LOG_FILE
exit 0
