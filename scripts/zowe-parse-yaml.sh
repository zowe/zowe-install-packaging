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

# Set Zowe configuration environment variables based on config file.
# Called by zowe-set-envvars.sh
#
# CALLED WITH SHELL SHARING (. script.sh), set $rc to indicate error
#
# Arguments:
# file  file to parse, default $INSTALL_DIR/install/zowe.yaml
#
# Expected globals:
# $debug $LOG_FILE $INSTALL_DIR $ZOWE_VERSION
#
# Alters:
# $line $key $section $value $default $rc $orig_me
# 
# $rc:
# 0: all good
# 8: error

orig_me=$me                    # original $me, $saved_me is already in use
me=zowe-parse-yaml.sh          # no $(basename $0) with shell sharing
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo "> $me $@"
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

# ---------------------------------------------------------------------
# --- parse configuration file
# $1: file to parse
# ---------------------------------------------------------------------
function _parseConfiguationFile
{
unset section                # ensure we evaluate something we have set

while read line
do
  # leading blanks are already stripped by read
  test -z "${line%%#*}" && continue      # skip line if first char is #
  test "$debug" && echo "line    $line"

  key=${line%%=*}                      # keep up to first = (exclusive)
  test "$debug" && echo "key     $key"
  if test "$(echo $key | grep :$)"         # is last char of $key a : ?
  then                                     # yes -> new section
    section=${key%%:}                  # keep up to first : (exclusive)
    test "$debug" && echo "section $section"
  else                                     # no -> key=value pair
    value=${line#*=}                    # keep from first = (exclusive)
    test "$debug" && echo "value   $value"
    # format: _export section key environment_variable default_value
# install
    _export install rootDir ZOWE_ROOT_DIR "~/zowe/$ZOWE_VERSION"
    _export install hlq     ZOWE_HLQ      $(id -nu).ZWE
# external
    _export external nodeHome        NODE_HOME          /usr/lpp/IBM/cnj
    _export external javaHome        ZOWE_JAVA_HOME     /usr/lpp/java/J8.0_64
    _export external zosmfPort       ZOWE_ZOSMF_PORT    443
    _export external zosmfConfigPath ZOWE_ZOSMF_PATH    /var/zosmf/configuration/servers/zosmfServer
    _export external hostName        ZOWE_EXPLORER_HOST $(hostname -c)
    _export external hostIP          ZOWE_IPADDRESS     $(host $(hostname -c) | awk '/has addresses/{print $NF}')
# terminals
    _export terminals sshPort    ZOWE_ZLUX_SSH_PORT      22
    _export terminals telnetPort ZOWE_ZLUX_TELNET_PORT   23
    _export terminals security   ZOWE_ZLUX_SECURITY_TYPE
# datasets
    _export datasets proclib ZOWE_PROCLIB $(id -nu).ZWE.CUST.PROCLIB
    _export datasets parmlib ZOWE_PARMLIB $(id -nu).ZWE.CUST.PARMLIB
    _export datasets jcl     ZOWE_JCLLIB  $(id -nu).ZWE.CUST.JCL
# zos-services
    _export zos-services jobsAPIPort ZOWE_EXPLORER_SERVER_JOBS_PORT     7080
    _export zos-services mvsAPIPort  ZOWE_EXPLORER_SERVER_DATASETS_PORT 8547
# zlux-server
    _export zlux-server httpsPort ZOWE_ZLUX_SERVER_HTTPS_PORT 8544
    _export zlux-server zssPort   ZOWE_ZSS_SERVER_PORT        8542
# zowe-desktop-apps
    _export zowe-desktop-apps jobsExplorerPort ZOWE_EXPLORER_JES_UI_PORT 8546
    _export zowe-desktop-apps mvsExplorerPort  ZOWE_EXPLORER_MVS_UI_PORT 8548
    _export zowe-desktop-apps ussExplorerPort  ZOWE_EXPLORER_USS_UI_PORT 8550
# api-mediation
    _export api-mediation catalogPort                    ZOWE_APIM_CATALOG_PORT   7552
    _export api-mediation discoveryPort                  ZOWE_APIM_DISCOVERY_PORT 7553
    _export api-mediation gatewayPort                    ZOWE_APIM_GATEWAY_PORT   7554
    _export api-mediation enableSso                      ZOWE_APIM_ENABLE_SSO     false
    _export api-mediation externalCertificate            ZOWE_APIM_EXTERNAL_CERTIFICATE
    _export api-mediation externalCertificateAlias       ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS
    _export api-mediation externalCertificateAuthorities ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES
    _export api-mediation verifyCertificatesOfServices   ZOWE_APIM_VERIFY_CERTIFICATES
    _export api-mediation zosmfKeyring                   ZOWE_ZOSMF_KEYRING IZUKeyring.IZUDFLT
    _export api-mediation zosmfUserid                    ZOWE_ZOSMF_USERID  IZUSVR
# zowe-server-proclib
    _export zowe-server-proclib dsName     ZOWE_SERVER_PROCLIB_MEMBER ZOWESVR
    _export zowe-server-proclib memberName ZOWE_SERVER_PROCLIB_DSNAME auto
  fi    # process key=value
done < $1
}    # parseConfiguationFile

# ---------------------------------------------------------------------
# --- set and export environment variable if section and key match
#     assumes $section $key $value are set
# $1: section must match this value
# $2: key must match this value
# $3: environment variable that will be set and exported
# $4: (optional) default value
# ---------------------------------------------------------------------
function _export
{
 if test "$section" = $1 -a "$key" = $2
 then
   # Is default value used?
   unset default
   test -z "$value" && default="  # default"

   # Export
   test "$debug" && echo "eval export $3=${value:-$4} 2>&1 $default"
   eval export $3="${value:-$4}" 2>&1

   if test $? -ne 0
   then
     # Error details already reported
     echo "** ERROR $me export $3=${value:-$4} failed"
     rc=8
   fi    #

   # Expand references like ~
   if test $3 = "ZOWE_ROOT_DIR"
   then
     export ZOWE_ROOT_DIR=`sh -c "echo $ZOWE_ROOT_DIR"`
   fi    #

   # Do not echo the ssh and telnet ports because unlike the others,
   # which Zowe needs to be free to alllocate and use, the ssh and
   # telnet ports are already being used and are exploited by Zowe.
   # Echoing them may create confusion.
   if test ! $3 = "ZOWE_ZLUX_SSH_PORT" \
        -a ! $3 = "ZOWE_ZLUX_TELNET_PORT"
   then
     echo "  $3=${value:-$4} $default" >> $LOG_FILE
   fi    # not suppressed
 fi    # section & key match
}    # _export

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing
unset rc

_parseConfiguationFile ${1:-$INSTALL_DIR/install/zowe.yaml}

# If not set, set rc to 0
test -z "$rc" && rc=0

test "$debug" && echo "< $me $rc"
echo "</$me> $rc" >> $LOG_FILE
me=$orig_me
# no exit, shell sharing with caller
