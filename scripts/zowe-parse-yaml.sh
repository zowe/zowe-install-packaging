#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2019, 2019
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
# $ZoWe_RoOt_DiR $ZoWe_HlQ $ZoWe_HlQ_cUsT
# $orig_me $rc
# $hostName $hostIP $hostPing
# $line $key $section $value $default
#
# $rc:
# 0: all good
# 8: error

ZoWe_UsEr_DiR="~/zowe-user-dir"
ZoWe_RoOt_DiR="~/zowe/$ZOWE_VERSION"
     ZoWe_HlQ="$(id -nu).ZWE$ZOWE_VERSION2"
ZoWe_HlQ_cUsT="$(id -nu).ZWE$ZOWE_VERSION2.CUST"
orig_me=$me                 # original $me, $saved_me is already in use
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
function _parseConfigurationFile
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
# todo
    _export todo userDir ZOWE_USER_DIR ${ZoWe_UsEr_DiR}
    _export todo zssCrossMemoryServerName ZOWE_ZSS_XMEM_SERVER_NAME
    _export todo dsname ZOWE_SERVER_PROCLIB_DSNAME
    _export todo memberName ZOWE_SERVER_PROCLIB_MEMBER
# install
    _export install rootDir ZOWE_ROOT_DIR ${ZoWe_RoOt_DiR}
    _export install hlq     ZOWE_HLQ      ${ZoWe_HlQ}
# external
    _export external nodeHome   NODE_HOME               /usr/lpp/IBM/cnj
    _export external javaHome   JAVA_HOME               /usr/lpp/java/J8.0_64
    _export external hostName   ZOWE_EXPLORER_HOST      $hostName
    _export external hostIP     ZOWE_IPADDRESS          $hostIP
    _export external sshPort    ZOWE_ZLUX_SSH_PORT      22
    _export external telnetPort ZOWE_ZLUX_TELNET_PORT   23
    _export external security   ZOWE_ZLUX_SECURITY_TYPE
# zosmf
    _export zosmf zosmfPort       ZOWE_ZOSMF_PORT        443
    _export zosmf zosmfConfigPath ZOWE_ZOSMF_PATH        /var/zosmf/configuration/servers/zosmfServer
    _export zosmf zosmfUserid     ZOWE_ZOSMF_USERID      IZUSVR
    _export zosmf zosmfAdminGroup ZOWE_ZOSMF_ADMIN_GROUP IZUADMIN
    _export zosmf zosmfKeyring    ZOWE_ZOSMF_KEYRING     IZUKeyring.IZUDFLT
# datasets
    _export datasets proclib ZOWE_PROCLIB "${ZoWe_HlQ_cUsT}.PROCLIB"
    _export datasets parmlib ZOWE_PARMLIB "${ZoWe_HlQ_cUsT}.PARMLIB"
    _export datasets jcllib  ZOWE_JCLLIB  "${ZoWe_HlQ_cUsT}.JCL"
# admin
    _export admin prefix     ZOWE_PREFIX      ZOWE
    _export admin instance   ZOWE_INSTANCE    1
    _export admin config     ZOWE_ETC_CFG
    _export admin adminGroup ZOWE_ADMIN_GROUP ZWEADMIN
# servers
    _export servers zoweSTC  ZOWE_STC_ZOWE  ZOWESVR
    _export servers zoweUser ZOWE_USER_ZOWE ZOWEUSR
    _export servers zssSTC   ZOWE_STC_ZSS   ZOWEZSS
    _export servers zssUser  ZOWE_USER_ZSS  ZSSUSR
# TODO currently not used as variable
#    _export servers stcGroup ZOWE_STC_GROUP STCGROUP
    _export servers jobCard1 ZOWE_JOBCARD1
    _export servers jobCard2 ZOWE_JOBCARD2
# zos-services
    _export zos-services jobsAPIPort ZOWE_EXPLORER_SERVER_JOBS_PORT     8545
    _export zos-services mvsAPIPort  ZOWE_EXPLORER_SERVER_DATASETS_PORT 8547
# zlux-server
    _export zlux-server httpsPort ZOWE_ZLUX_SERVER_HTTPS_PORT 8544
    _export zlux-server zssPort   ZOWE_ZSS_SERVER_PORT        8542
    _export zlux-server nodeLogs  ZLUX_NODE_LOG_DIR           ${TMPDIR:-/tmp}
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
  fi    # process key=value
done < $1
}    # _parseConfigurationFile

# ---------------------------------------------------------------------
# --- get host TCP/IP data (failure results in null value)
# ---------------------------------------------------------------------
function _getHost
{
unset hostIP
test "$debug" && echo ". hostname"
hostName="$(hostname)" 2>/dev/null

if test -n "$hostName"
then
  # 'hostname' can return alias instead of host and domain name
  # >hostname
  # S0W1
  # 'host' might return multiple addresses and/or aliases
  # >host
  # EZZ8321I S0W1.IHOST.COM has addresses 10.1.1.2
  # EZZ8322I aliases: S0W1

  # Use ping to expand the host name and limit possible variables.
  # >ping S0W1
  # CS V2R3: Pinging host S0W1.IHOST.COM (10.1.1.2)
  # Ping #1 response took 0.003 seconds.

  test "$debug" && echo ". ping $hostName"
  hostPing="$(ping $hostName)" 2>/dev/null

  if test -n "$hostPing"
  then
    hostName="$(echo $hostPing | sed -n 's/.* host \(.*\) (.*/\1/p')"
    hostIP="$(echo $hostPing | sed -n 's/.* (\(.*\)).*/\1/p')"
  fi    # ping
fi    # hostname

test "$debug" && echo "hostName=$hostName"
test "$debug" && echo "hostIP=$hostIP"
}    # _getHost

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
  if test $3 = "ZOWE_USER_DIR"
  then
    export ZOWE_USER_DIR=`sh -c "echo $ZOWE_USER_DIR"`
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

# Get TCP/IP values to set defaults (no error reporting)
_getHost

# Process config file
_parseConfigurationFile ${1:-$INSTALL_DIR/install/zowe.yaml}

# If not set, set rc to 0
test -z "$rc" && rc=0

test "$debug" && echo "< $me $rc"
echo "</$me> $rc" >> $LOG_FILE
me=$orig_me
# no exit, shell sharing with caller
