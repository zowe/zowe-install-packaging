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

# Configure the Zowe API Mediation Layer.
# Called by zowe-configure.sh
#
# Arguments:
# /
#
# Expected globals:
# $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR
#
# caller needs these RACF permits when install is done by another ID:
# TSO PE SUPERUSER.FILESYS.CHANGEPERMS CL(UNIXPRIV) ACCESS(READ) ID(userid)

here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- API mediation"
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
# --- customize a file using sed and save in codepage IBM850,
#     optionally creating a new output file
#     assumes $SED is defined by caller and holds sed command string
# $1: if -x then make result executable, parm is removed when present
# $1: input file
# $2: (optional) output file, default is $1
# ---------------------------------------------------------------------
function _sed850
{
unset ExEc
if test "$1" = "-x"
then                                     # make exectuable after update
  shift
  ExEc=1
fi    #

TmP=$TMPDIR/$(basename $1)
_cmd --repl $TmP sed $SED $1                      # sed '...' $1 > $TmP
_cmd --repl ${2:-$1} iconv -f IBM-1047 -t IBM-850 $TmP
_cmd chtag -tc IBM-850 ${2:-$1}             # tag as pure text in cp850
_cmd rm -f $TmP
test -n "$ExEc" && _cmd chmod a+x ${2:-$1}            # make executable
}    # _sed850

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

STATIC_DEF_CONFIG="$ZOWE_ROOT_DIR/api-mediation/api-defs"

# Get z/OSMF version (this matches z/OS version)
ZOSMF_VERSION=$($scripts/get-OS-version.rex) 2>&1
test "$debug" && echo "ZOSMF_VERSION=$ZOSMF_VERSION"       # e.g. 2.3.0
vr=$(echo $ZOSMF_VERSION | awk -F '.' '{printf "v%dr%d\n",$1,$2}')
test "$debug" && echo "vr=$vr"                             # e.g. v2r3

# Get z/OSMF documetation URL 
case "$ZOSMF_VERSION" in
  version-with-special-link | or-other-special ) 
    ZOSMF_DOC_URL="something-special"
    ;;
  * )
    ZOSMF_DOC_URL="https://www.ibm.com/support/knowledgecenter/en"
    ZOSMF_DOC_URL="${ZOSMF_DOC_URL}/SSLTBW_${ZOSMF_VERSION}"
    ZOSMF_DOC_URL="${ZOSMF_DOC_URL}/com.ibm.zos.${vr}.izua700"
    ZOSMF_DOC_URL="${ZOSMF_DOC_URL}/IZUHPINFO_RESTServices.htm"
    ;;
esac    # case $ZOSMF_VERSION
test "$debug" && echo "ZOSMF_DOC_URL=$ZOSMF_DOC_URL"

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# TODO ship static defintions as files & only customize here
# TODO write entries in $LOG_FILE

# Add static definition for zosmf	
file=zosmf.yml
echo "  creating $STATIC_DEF_CONFIG/$file" >> $LOG_FILE
test "$debug" && echo
test "$debug" && echo "cat <<EOF 2>&1 >$TMPDIR/$file"
cat <<EOF 2>&1 >$TMPDIR/$file
# Static definition for z/OSMF
#
# Once configured you can access z/OSMF via the API gateway:
# http --verify=no GET https://$ZOWE_EXPLORER_HOST:$ZOWE_APIM_GATEWAY_PORT/api/v1/zosmf/info 'X-CSRF-ZOSMF-HEADER;'
#	
services:
    - serviceId: zosmf
      title: IBM z/OSMF
      description: IBM z/OS Management Facility REST API service
      catalogUiTileId: zosmf
      instanceBaseUrls:
        - https://$ZOWE_EXPLORER_HOST:$ZOWE_ZOSMF_PORT/zosmf/
      homePageRelativeUrl:  # Home page is at the same URL
      routedServices:
        - gatewayUrl: api/v1  # [api/ui/ws]/v{majorVersion}
          serviceRelativeUrl:
      apiInfo:
        - apiId: com.ibm.zosmf
          gatewayUrl: api/v1
          version: $ZOSMF_VERSION
          documentationUrl: $ZOSMF_DOC_URL

catalogUiTiles:
    zosmf:
        title: z/OSMF services
        description: IBM z/OS Management Facility REST services
EOF
if test $? -ne 0
then
  echo "** ERROR $me creating $file failed"
  echo "ls -ld \"$TMPDIR/$file\""; ls -ld "$TMPDIR/$file"
  rc=8
fi    #
_cmd --repl $STATIC_DEF_CONFIG/$file \
  iconv -f IBM-1047 -t IBM-850 $TMPDIR/$file 
_cmd rm -f $TMPDIR/$file
# No original to save, but add customized one so restore can process it
_backup $STATIC_DEF_CONFIG/$file

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Add static definition for MVS datasets
file=datasets.yml
echo "  creating $STATIC_DEF_CONFIG/$file" >> $LOG_FILE
test "$debug" && echo
test "$debug" && echo "cat <<EOF 2>&1 >$TMPDIR/$file"
cat <<EOF 2>&1 >$TMPDIR/$file
#
services:
  - serviceId: datasets
    title: IBM z/OS Datasets
    description: IBM z/OS Datasets REST API service
    catalogUiTileId: datasetsAndUnixFiles
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_DATASETS_PORT/
    homePageRelativeUrl:  # Home page is at the same URL
    routedServices:
      - gatewayUrl: api/v1  # [api/ui/ws]/v{majorVersion}
        serviceRelativeUrl: api/v1/datasets
    apiInfo:
      - apiId: org.zowe.data.sets
        gatewayUrl: api/v1
        version: 1.0.0
        documentationUrl: https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_DATASETS_PORT/swagger-ui.html
  - serviceId: unixfiles
    title: IBM z/OS Unix Files
    description: IBM z/OS Unix Files REST API service
    catalogUiTileId: datasetsAndUnixFiles
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_DATASETS_PORT/
    homePageRelativeUrl:  # Home page is at the same URL
    routedServices:
      - gatewayUrl: api/v1  # [api/ui/ws]/v{majorVersion}
        serviceRelativeUrl: api/v1/unixfiles 
    apiInfo:
      - apiId: org.zowe.unix.files
        gatewayUrl: api/v1
        version: 1.0.0
        documentationUrl: https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_DATASETS_PORT/swagger-ui.html
  - serviceId: explorer-mvs
    title: IBM z/OS MVS Explorer UI
    description: IBM z/OS MVS Explorer UI service
    catalogUiTileId:
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_MVS_UI_PORT/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: ui/v1
        serviceRelativeUrl: ui/v1/explorer-mvs
catalogUiTiles:
  datasetsAndUnixFiles:
    title: z/OS Datasets and Unix Files services
    description: IBM z/OS Datasets and Unix Files REST services
EOF
if test $? -ne 0
then
  echo "** ERROR $me creating $file failed"
  echo "ls -ld \"$TMPDIR/$file\""; ls -ld "$TMPDIR/$file"
  rc=8
fi    #
_cmd --repl $STATIC_DEF_CONFIG/$file \
  iconv -f IBM-1047 -t IBM-850 $TMPDIR/$file 
_cmd rm -f $TMPDIR/$file
# No original to save, but add customized one so restore can process it
_backup $STATIC_DEF_CONFIG/$file

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Add static definition for Jobs
file=jobs.yml
echo "  creating $STATIC_DEF_CONFIG/$file" >> $LOG_FILE
test "$debug" && echo
test "$debug" && echo "cat <<EOF 2>&1 >$TMPDIR/$file"
cat <<EOF 2>&1 >$TMPDIR/$file
#
services:
  - serviceId: jobs
    title: IBM z/OS Jobs
    description: IBM z/OS Jobs REST API service
    catalogUiTileId: jobs
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_JOBS_PORT/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: api/v1
        serviceRelativeUrl: api/v1/jobs
    apiInfo:
      - apiId: com.ibm.jobs
        gatewayUrl: api/v1
        version: 1.0.0
        documentationUrl: https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_SERVER_JOBS_PORT/swagger-ui.html
  - serviceId: explorer-jes
    title: IBM z/OS Jobs UI
    description: IBM z/OS Jobs UI service
    catalogUiTileId:
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_JES_UI_PORT/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: ui/v1
        serviceRelativeUrl: ui/v1/explorer-jes
catalogUiTiles:
  jobs:
    title: z/OS Jobs services
    description: IBM z/OS Jobs REST services
EOF
if test $? -ne 0
then
  echo "** ERROR $me creating $file failed"
  echo "ls -ld \"$TMPDIR/$file\""; ls -ld "$TMPDIR/$file"
  rc=8
fi    #
_cmd --repl $STATIC_DEF_CONFIG/$file \
  iconv -f IBM-1047 -t IBM-850 $TMPDIR/$file 
_cmd rm -f $TMPDIR/$file
# No original to save, but add customized one so restore can process it
_backup $STATIC_DEF_CONFIG/$file

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Add static definition for USS
file=uss.yml
echo "  creating $STATIC_DEF_CONFIG/$file" >> $LOG_FILE
test "$debug" && echo
test "$debug" && echo "cat <<EOF 2>&1 >$TMPDIR/$file"
cat <<EOF 2>&1 >$TMPDIR/$file
#
services:
  - serviceId: explorer-uss
    title: IBM Unix System Services
    description: IBM z/OS Unix System services UI
    instanceBaseUrls:
      - https://$ZOWE_EXPLORER_HOST:$ZOWE_EXPLORER_USS_UI_PORT/
    homePageRelativeUrl:
    routedServices:
      - gatewayUrl: ui/v1
        serviceRelativeUrl: ui/v1/explorer-uss
EOF
if test $? -ne 0
then
  echo "** ERROR $me creating $file failed"
  echo "ls -ld \"$TMPDIR/$file\""; ls -ld "$TMPDIR/$file"
  rc=8
fi    #
_cmd --repl $STATIC_DEF_CONFIG/$file \
  iconv -f IBM-1047 -t IBM-850 $TMPDIR/$file 
_cmd rm -f $TMPDIR/$file
# No original to save, but add customized one so restore can process it
_backup $STATIC_DEF_CONFIG/$file

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# TODO really 777 for $STATIC_DEF_CONFIG ?
_cmd chmod -R 777 $STATIC_DEF_CONFIG

# API Mediation certificate generation
_cmd $scripts/zowe-configure-apiml-certificates.sh

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
exit 0
