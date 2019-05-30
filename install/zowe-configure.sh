#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# 5698-ZWE Copyright Contributors to the Zowe Project. 2018, 2019
#######################################################################

#% Configure Zowe.
#%
#% Invocation arguments:
#% -?                    show this help message
#% -c zowe-install.yaml  configure Zowe using the specified input file
#% -d                    enable debug messages
#% -f logFile            write script log in the specified file
#% -l logDir             write script log in the specified directory
#%                       ignored when -f is also specified
#% -t tempDir            directory for temporary configuration data
#%
#% If -c is not specified, then Zowe is configured using default
#% values.
#%
#% caller needs these RACF permits when install is done by another ID:
#% TSO PE SUPERUSER.FILESYS.CHANGEPERMS CL(UNIXPRIV) ACCESS(READ) ID(userid)

# ---------------------------------------------------------------------
# --- execute steps to configure Zowe
# ---------------------------------------------------------------------
function _config
{
_separator
echo "-- Beginning configuration of Zowe $ZOWE_VERSION using $ZOWE_YAML" 
_cmd umask 0022                                  # similar to chmod 755

# Warn about configuring something else as current install
if test "$INSTALL_DIR" != "$ZOWE_ROOT_DIR"
then
  echo "** WANRING target directory $ZOWE_ROOT_DIR does not match" \
    "script directory $INSTALL_DIR" | tee -a $LOG_FILE
fi    #

# Test for missing/incorrect installation
if test -f "$ZOWE_ROOT_DIR/manifest.json"
then                                                  # manifest exists
  # Extract Zowe version from manifest.json
  # sample input:
  #   "version": "1.0.0",
  # sed will:
  # -n '...p' only print lines that match
  # /"version"/ only process lines that have the characters `"version"`
  # s/.../\1/ substitute whole line with a marked section of the line
  # .*: "     all characters from begin up till last `: "` (inclusive)
  # \(        begin marker for section of line
  # [^"]*     all characters from current position to first " (exclusive)
  # \)        end marker for section of line
  # .*        all characters from current position to end of line
  # sample output:
  # 1.0.0
  target_version=$(sed -n '/"version"/s/.*: "\([^"]*\).*/\1/p' \
    $ZOWE_ROOT_DIR/manifest.json)
  test "$debug" && echo target_version=$target_version
  if test "$ZOWE_VERSION" != "$target_version"
  then
    echo "** ERROR $ZOWE_ROOT_DIR holds Zowe $target_version and this" \
      "script is expecting Zowe $ZOWE_VERSION" | tee -a $LOG_FILE
    echo "   Please install Zowe $ZOWE_VERSION first, or correct" \
      "$ZOWE_YAML before attempting the configuration."
    echo "Configuration terminated"
    test ! "$ignore_error" && exit 1                             # EXIT
  fi    #
else                                          # manifest does not exist
  echo "** ERROR $ZOWE_ROOT_DIR does not hold Zowe" | tee -a $LOG_FILE
  echo "   Please install Zowe $ZOWE_VERSION first, or correct" \
    "$ZOWE_YAML before attempting the configuration."
  echo "Configuration terminated"
  test ! "$ignore_error" && exit 1                               # EXIT
fi    # missing/incorrect Zowe

# ---

# Set TEMP_DIR & create directory if needed
TEMP_DIR=${TEMP_DIR:-$INSTALL_DIR/temp_$(date +%Y-%m-%d-%H-%M-%S).$$}
export TEMP_DIR
test "$debug" && echo TEMP_DIR=$TEMP_DIR
_cmd mkdir -p $TEMP_DIR
test ! -w $TEMP_DIR && chmod a+rwx $TEMP_DIR 2>/dev/null
if test ! -w $TEMP_DIR
then
  echo "** ERROR no write access for -t $TEMP_DIR" | tee -a $LOG_FILE
  echo "ls -ld \"$TEMP_DIR\""; ls -ld "$TEMP_DIR"
  echo "Configuration terminated"
  test ! "$ignore_error" && exit 1                               # EXIT
fi    #

# ---

echo "-- directory listing of $ZOWE_ROOT_DIR before config" >> $LOG_FILE
ls -A $ZOWE_ROOT_DIR | sed 's/^/  /' >> $LOG_FILE
echo "--" >> $LOG_FILE

# TODO remove, moved to zowe.yaml
# # Populate the environment variables for runtime activity
# _cmd . $INSTALL_DIR/scripts/zowe-configure-init.sh

# Configure Explorer UI plugins
_cmd $INSTALL_DIR/scripts/zowe-configure-explorer-ui.sh

# Configure the ports for the zLUX server
_cmd $INSTALL_DIR/scripts/zowe-configure-zlux-ports.sh

# Configure the TLS certificates for the zLUX server
_cmd $INSTALL_DIR/scripts/zowe-configure-zlux-certificates.sh

# TODO revisit to work out the best permissions,
# but currently needed so deploy.sh can run
_cmd chmod -R 775 $ZOWE_ROOT_DIR/zlux-app-server/plugins/
_cmd chmod -R 775 $ZOWE_ROOT_DIR/zlux-app-server/deploy/product
_cmd chmod -R 775 $ZOWE_ROOT_DIR/zlux-app-server/deploy/instance

# Configure access to API Catalog
if test "$ZOWE_APIM_ENABLE_SSO" != "true"
then                                      # Access API Catalog directly
  CATALOG_GATEWAY_URL=https://$ZOWE_EXPLORER_HOST:$ZOWE_APIM_GATEWAY_PORT/ui/v1/apicatalog
else                          # Add APIML authentication plugin to zLUX
  _cmd $INSTALL_DIR/scripts/zowe-add-zlux-plugin.sh \
     $ZOWE_ROOT_DIR \
     "org.zowe.zlux.auth.apiml" \
     $ZOWE_ROOT_DIR/api-mediation/apiml-auth

  # Activate the plugin
  SED='"apiml": { "plugins": ["org.zowe.zlux.auth.apiml"] }'
  SED='s/"zss": {/'"$SED"', "zss": {/g'
  _sed $ZOWE_ROOT_DIR/zlux-app-server/config/zluxserver.json

  # Access API Catalog with token injector
  CATALOG_GATEWAY_URL=https://$ZOWE_EXPLORER_HOST:$ZOWE_ZLUX_SERVER_HTTPS_PORT/ZLUX/plugins/org.zowe.zlux.auth.apiml/services/tokenInjector/1.0.0/ui/v1/apicatalog/
fi    # Configure access to API Catalog

# Add API Catalog application to zLUX
# required before we issue zLUX deploy.sh
_cmd $INSTALL_DIR/scripts/zowe-add-zlux-iframe-plugin.sh \
  $ZOWE_ROOT_DIR \
  "org.zowe.api.catalog" \
  "API Catalog" \
  $CATALOG_GATEWAY_URL \
  $ZOWE_ROOT_DIR/files/assets/api-catalog.png

# Run deploy on the zLUX app server to propagate the changes made
silent="-s"
test "$debug" && unset silent
_cmd $ZOWE_ROOT_DIR/zlux-build/deploy.sh $silent

_separator  # . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Configure API Mediation layer.
# Because this script may fail because of privilege issues with the
# user ID this script is run after all the folders have been created
# and paxes expanded
echo "Attempting to setup Zowe API Mediation Layer certificates ..."
_cmd $INSTALL_DIR/scripts/zowe-configure-api-mediation.sh

# Configure Explorer API servers.
# This should be after APIML CM generated certificates
echo "Attempting to setup Zowe Explorer API certificates ..."
_cmd $INSTALL_DIR/scripts/zowe-configure-explorer-api.sh

_separator  # . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Create the /scripts folder in the runtime directory
# where the scripts to start and the Zowe server will be coped into
echo "Attempting to set Unix file permissions ..."
_cmd mkdir -p $ZOWE_ROOT_DIR/scripts
_cmd chmod a+w $ZOWE_ROOT_DIR/scripts

# The file zowe-runtime-authorize.sh is in the install directory
# /scripts. Copy this to the runtime directory /scripts, and replace
# {ZOWE_ZOSMF_PATH} with where ZOSMF is located, so that the script
# can create symlinks and if it fails be able to be run stand-alone
SCRIPT=$ZOWE_ROOT_DIR/scripts/zowe-runtime-authorize.sh
echo "Updating $SCRIPT" >> $LOG_FILE
SED="s#%zosmfpath%#$ZOWE_ZOSMF_PATH#g"
_sed $SCRIPT                          # note, INSTALL_DIR=ZOWE_ROOT_DIR
_cmd chmod a+x $SCRIPT

test "$debug" && echo $SCRIPT
$SCRIPT
if test $? -eq 0
then
  echo "  The permissions were successfully changed"
  echo "  $SCRIPT run successfully" >> $LOG_FILE
else
  echo "** ERROR The current user does not have sufficient"\
    " authority to modify all the file and directory permissions."
  echo "  A user with sufficient authority must run $OUT"
  echo "  $SCRIPT failed to run successfully" >> $LOG_FILE
  test ! "$ignore_error" && exit 1                               # EXIT
fi    #

_separator  # . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

echo "Attempting to create $ZOWE_SERVER_PROCLIB_MEMBER PROCLIB member ..."
# Create the ZOWESVR JCL
# Insert the default Zowe install path in the JCL

echo "Copying the zowe-start;stop;server-start.sh into "$ZOWE_ROOT_DIR/scripts >> $LOG_FILE
cd $INSTALL_DIR/scripts
SED="s/ZOWESVR/$ZOWE_SERVER_PROCLIB_MEMBER/"
_sed $ZOWE_ROOT_DIR/scripts/zowe-start.sh   # INSTALL_DIR=ZOWE_ROOT_DIR
_sed $ZOWE_ROOT_DIR/scripts/zowe-stop.sh    # INSTALL_DIR=ZOWE_ROOT_DIR
# skip because INSTALL_DIR=ZOWE_ROOT_DIR
#_cmd cp $INSTALL_DIR/scripts/zowe-verify.sh \
#  $ZOWE_ROOT_DIR/scripts/zowe-verify.sh
_cmd chmod -R 777 $ZOWE_ROOT_DIR/scripts

INTERNAL=$ZOWE_ROOT_DIR/scripts/internal
_cmd mkdir -p $INTERNAL
_cmd chmod a+x $INTERNAL

echo "Copying the opercmd into $INTERNAL" >> $LOG_FILE
_cmd cp $INSTALL_DIR/scripts/opercmd $INTERNAL/opercmd

echo "Copying the run-zowe.sh into $INTERNAL" >> $LOG_FILE
SED="s|\$nodehome|$NODE_HOME|"
_sed $INSTALL_DIR/scripts/run-zowe.sh $INTERNAL/run-zowe.sh

_cmd chmod -R 755 $INTERNAL

SED="s|/zowe/install/path|$ZOWE_ROOT_DIR|"
_sed $INSTALL_DIR/files/templates/ZOWESVR.jcl
$INSTALL_DIR/scripts/zowe-copy-proc.sh \
  $INSTALL_DIR/files/templates/ZOWESVR.jcl \
  $ZOWE_SERVER_PROCLIB_MEMBER \
  $ZOWE_SERVER_PROCLIB_DSNAME

_separator  # . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

echo "To start Zowe run the script $ZOWE_ROOT_DIR/scripts/zowe-start.sh"
echo "   (or in SDSF directly issue the command /S $ZOWE_SERVER_PROCLIB_MEMBER)"
echo "To stop Zowe run the script $ZOWE_ROOT_DIR/scripts/zowe-stop.sh"
echo "  (or in SDSF directly the command /C $ZOWE_SERVER_PROCLIB_MEMBER)"

# Save install log in runtime directory
_cmd mkdir $ZOWE_ROOT_DIR/setup_log
_cmd cp $LOG_FILE $ZOWE_ROOT_DIR/setup_log

# Remove the working directory
_cmd rm -rf $TEMP_DIR

echo "-- Completed configuration of Zowe $ZOWE_VERSION using $ZOWE_YAML" 
}    # _config

# ---------------------------------------------------------------------
# --- customize a file using sed, optionally creating a new output file
#     assumes $SED is defined by caller and holds sed command string
# $1: input file
# $2: (optional) output file, default is $1
# ---------------------------------------------------------------------
function _sed
{
TmP=$TEMP_DIR/$(basename $1)
test -f $TmP && _cmd rm -f $TmP                 # remove $TmP if exists
_cmd --save $TmP sed $SED $1                    # sed '...' $1 >> $TmP
_cmd cp $TmP ${2:-$1}                           # give $TmP actual name
_cmd rm $TmP                                    # remove $TmP
}    # _sed

# ---------------------------------------------------------------------
# --- display script usage information
# ---------------------------------------------------------------------
function _displayUsage
{
echo " "
echo " $(basename $0)"
sed -n 's/^#%//p' $(whence $0)
echo " "
}    # _displayUsage

# ---------------------------------------------------------------------
# --- create separator line
# ---------------------------------------------------------------------
_separator()
{
echo "----------------------------------------------------------------"
}    # _separator

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $2: if $1 = --save then target receiving stdout
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
then         # stdout -> $2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 >> $sAvE"
                         $@ 2>&1 >> $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "$@ 2>&1"
                         $@ 2>&1
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** ERROR '$@' ended with status $sTaTuS"
  test ! "$ignore_error" && exit 1                               # EXIT
fi    #
}    # _cmd

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing
export _EDC_ADD_ERRNO2=1                        # show details on error
# .profile with ENV=script with echo -> echo is in stdout (begin)
unset ENV

echo
echo "-- $(basename $0) -- $(sysvar SYSNAME) -- $(date)"
echo "-- startup arguments: $@"

# Clear input variables
unset LOG_FILE LOG_DIR TEMP_DIR ZOWE_YAML ZOWE_ROOT_DIR
# do NOT unset debug
# always unset ZOWE_ROOT_DIR

# Get startup arguments
while getopts c:f:l:t:d? opt
do case "$opt" in
  c)   export ZOWE_YAML="$OPTARG";;
  d)   export debug=1;;
  f)   export LOG_FILE="$OPTARG";;
  l)   export LOG_DIR="$OPTARG";;
  t)   export TEMP_DIR="$OPTARG";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR faulty startup argument: $@"
       echo "Configuration terminated"
       test ! "$ignore_error" && exit 1;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

# No install, only configuration
unset inst
conf=1

# Set all required environment variables & logging
# zowe-set-envvars.sh exports environment vars, so run in current shell
_cmd . $(dirname $0)/../scripts/zowe-set-envvars.sh

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# Configure Zowe
_config
