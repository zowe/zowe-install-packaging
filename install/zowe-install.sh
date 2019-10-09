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

#% Install and/or configure Zowe.
#%
#% Invocation arguments:
#% -?            show this help message
#% -C            configure Zowe using default input file
#%               ignored when -c is also specified
#% -c zowe.yaml  configure Zowe using the specified input file
#% -d            enable debug messages
#% -f logFile    write script log in the specified file
#% -h hlq        install Zowe in the specified data set high level qualifier
#% -I            install Zowe using default directory & hlq,
#%               unless overridden by -h and/or -i
#% -i rootDir    install Zowe in the specified directory
#% -l logDir     write script log in the specified directory
#%               ignored when -f is also specified
#% -R            remove source files after install               #debug
#%               ignored unless -h/i/I is also specified
#% -t tempDir    directory for temporary configuration data
#%               ignored unless -c/C is also specified
#%
#% If neither -c, or -C nor -h, -i, or -I is specified, then -C -I is
#% implied and Zowe is installed and configured using default values.
#%
#% caller needs these RACF permits:
#% (zowe-install-zlux.sh)
#% TSO PE BPX.FILEATTR.PROGCTL CL(FACILITY) ACCESS(READ) ID(userid)
#% TSO SETR RACLIST(FACILITY) REFRESH

here=$(cd $(dirname $0);pwd)   # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- initialization tasks that should move to the build pipeline
# ---------------------------------------------------------------------
function _pipeline
{
test "$debug" && echo && echo "> _pipeline $@"
echo "  pipeline tasks" >> $LOG_FILE

# TEST BEFORE TAKING ACTION
# actions could have been done in a previous install from same source

# TODO ship zss.pax extracted so all SAMPLIB can be processed together
if test -f $INSTALL_DIR/files/zss.pax
then
  _cmd $INSTALL_DIR/scripts/unpax.sh \
    "$INSTALL_DIR/files/zss.pax" \
    "$INSTALL_DIR/files/zss" \
    "ZSS"
fi    #

iDir=$INSTALL_DIR/files/zss/SAMPLIB
#_cmd mv $iDir/ZWESIP00 $iDir/ZWESIP00
_cmd mv $iDir/ZWESIS01 $iDir/ZWESISTC
#_cmd mv $iDir/ZWESISCH $iDir/ZWESISCH
_cmd mv $iDir/ZWESISMS $iDir/ZWESIPRG

# ---

# TODO rename data-sets-api-server-*.jar -> files-api-server-*.jar
for file in $(ls $INSTALL_DIR/files/data-sets-api-server-*.jar)
do                                           # ${#*} strips 'data-sets'
  _cmd mv $file $INSTALL_DIR/files/files${file#*data-sets}
done    # for file

# ---

test "$debug" && echo && echo "< _pipeline"
}    # _pipeline

# ---------------------------------------------------------------------
# --- execute steps to install Zowe
# ---------------------------------------------------------------------
function _install
{
test "$debug" && echo && echo "> _install $@"

# Create $ZOWE_ROOT_DIR
_cmd mkdir -p $ZOWE_ROOT_DIR

# Perform tasks that eventually should move to build pipeline
_pipeline

# Install the API Mediation Layer
_cmd $scripts/zowe-install-api-mediation.sh

# Install the Explorer APIs
_cmd $scripts/zowe-install-explorer-api.sh

# Install Explorer UI plugins
_cmd $scripts/zowe-install-explorer-ui.sh

# Install the zLUX server
_cmd $scripts/zowe-install-zlux.sh

# Install MVS data sets
_cmd $scripts/zowe-install-MVS.sh

# Install administrator scripts
# MUST run last as it kills scripts/* when $ReMoVe is active        #*/
#_cmd $scripts/zowe-install-admin.sh

# Update ZOWE_CFG variable with new file location
export ZOWE_CFG="adminDir/$(basename $ZOWE_CFG)"
echo ZOWE_CFG=$ZOWE_CFG | tee -a $LOG_FILE

# Set baseline for access permissions
_cmd chmod -R 755 $ZOWE_ROOT_DIR

# Remove install script if requested
test "$ReMoVe" && _cmd rm -f $0

test "$debug" && echo && echo "< _install"
}    # _install

# ---------------------------------------------------------------------
# --- verify that product can be installed
# ---------------------------------------------------------------------
function _verify
{
test "$debug" && echo && echo "> _verify $@"
# Test for any prior installation
# (this also covers installing in the directory holding install source)
if test -d "$ZOWE_ROOT_DIR"
then
  directoryListLines=$(ls -al $ZOWE_ROOT_DIR | wc -l)
  # Has total line, parent and self ref
  if test $directoryListLines -gt 3
  then
    echo "** ERROR $me $ZOWE_ROOT_DIR is not empty"
    echo "   Please clear the contents of this directory, or edit" \
      "zowe.yaml's root directory" \
      "location before attempting the install."
    echo "Exiting - non empty install directory $ZOWE_ROOT_DIR has" \
      $(expr $directoryListLines - 3) "directory entries" >> $LOG_FILE
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
fi    # prior install

test "$debug" && echo && echo "< _verify"
}    # _verify

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
# --- display script usage information
# ---------------------------------------------------------------------
function _displayUsage
{
echo " "
echo " $me"
sed -n 's/^#%//p' $(whence $0)
echo " "
}    # _displayUsage

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing
export _EDC_ADD_ERRNO2=1                        # show details on error
# .profile with ENV=script with echo -> echo is in stdout (begin)
# Ensure that newly created files are in EBCDIC codepage
unset ENV _CEE_RUNOPTS _TAG_REDIR_IN _TAG_REDIR_OUT _TAG_REDIR_ERR
export _BPXK_AUTOCVT="OFF"
_cmd umask 0022                                  # similar to chmod 755

echo
echo "-- $me -- $(sysvar SYSNAME) -- $(date)"
echo "-- startup arguments: $@"

# Clear input variables
unset LOG_FILE LOG_DIR TEMP_DIR inst conf ReMoVe
unset ZOWE_CFG ZOWE_ROOT_DIR ZOWE_HLQ
# do NOT unset debug
# always unset LOG_FILE

# Get startup arguments
# C/c & I/i constructs as getopts cannot handle optional OPTARG
while getopts c:f:h:i:l:t:CdIR? opt
do case "$opt" in
  C)   conf=1;;
  c)   conf=1
       export ZOWE_CFG="$OPTARG";;
  d)   export debug="-d";;
  f)   export LOG_FILE="$OPTARG";;
  h)   inst=1
       export ZOWE_HLQ="$OPTARG";;
  I)   inst=1;;
  i)   inst=1
       export ZOWE_ROOT_DIR="$OPTARG";;
  l)   export LOG_DIR="$OPTARG";;
  R)   export ReMoVe="-R";;
  t)   export TEMP_DIR="$OPTARG";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

# If nothing is specified then install & config Zowe using defaults
if test -z "$inst$conf"
then
  inst=1
  conf=1
fi    #

# Use specified temporary directory (note: TMPDIR is used by /bin/sh)
test -n "$TEMP_DIR" && TMPDIR=$TEMP_DIR

# Set all required environment variables & logging
# NOTE: script exports environment vars, so run in current shell
_cmd . $(dirname $0)/../scripts/zowe-set-envvars.sh $0

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

adminDir="$ZOWE_ROOT_DIR/admin"
#TODO rework, must currently match zowe-install-admin.sh
adminDir="$ZOWE_ROOT_DIR/scripts/configure"

# Install Zowe
if test -n "$inst"
then
  echo "-- Beginning install of Zowe $ZOWE_VERSION into directory" \
    "$ZOWE_ROOT_DIR and high level qualifier $ZOWE_HLQ"
  # LOG_FILE is already updated by zowe-set-envvars.sh

  # Ensure things are good to start install
  _verify

  # Install Zowe
  _install

  echo "-- Completed install of Zowe $ZOWE_VERSION into directory" \
    "$ZOWE_ROOT_DIR and high level qualifier $ZOWE_HLQ"
  echo "Installation completed -- $(date)" >> $LOG_FILE
fi    # install Zowe

# Configure Zowe
if test -n "$conf"
then
  # Determine required invocation arguments
  # Note: $ZOWE_CFG is already updated to point to the installed version
  args="$debug"
  args="$args -c $ZOWE_CFG"
  args="$args -f $LOG_FILE"
  test "$TEMP_DIR" && args="$args -t $TEMP_DIR"

  # Configure steps require that INSTALL_DIR matches ZOWE_ROOT_DIR,
  # remove the variable here so it can be set again with desired value
  unset INSTALL_DIR

  # Configure Zowe
  _cmd $adminDir/zowe-configure.sh $args
fi    # configure Zowe

test "$debug" && echo && echo "< $me 0"
exit 0
