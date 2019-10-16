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

#% Configure Zowe.
#%
#% Invocation arguments:
#% -?            show this help message
#% -c zowe.yaml  configure Zowe using the specified input file
#% -d            enable debug messages
#% -f logFile    write script log in the specified file
#% -l logDir     write script log in the specified directory
#%               ignored when -f is also specified
#% -t tempDir    directory for temporary configuration data
#%
#% If -c is not specified, then Zowe is configured using default
#% values.
#%
#% caller needs these RACF permits when install is done by another ID:
#% (zowe-configure-api-mediation.sh zowe-configure-zlux-authorize.sh)
#% TSO PE SUPERUSER.FILESYS.CHANGEPERMS CL(UNIXPRIV) ACCESS(READ) ID(userid)
#% (zowe-configure-zlux-authorize.sh)
#% TSO PE SUPERUSER.FILESYS.CHOWN CL(UNIXPRIV) ACCESS(READ) ID(userid)

here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo && echo "> $me $@"

# ---------------------------------------------------------------------
# --- execute steps to configure Zowe
# ---------------------------------------------------------------------
function _config
{
echo "-- directory listing of $ZOWE_ROOT_DIR before config" >> $LOG_FILE
ls -A $ZOWE_ROOT_DIR | sed 's/^/  /' >> $LOG_FILE

# Create customized PROCLIB members
_cmd $scripts/zowe-configure-proclib.sh

# Create customized PARMLIB members
_cmd $scripts/zowe-configure-parmlib.sh

# Create customized miscelaneous members
_cmd $scripts/zowe-configure-jcllib.sh

# Configure Explorer UI plugins, depends on Node
# TODO - ALTERS INSTALLED PRODUCT
_cmd $scripts/zowe-configure-explorer-ui.sh

# Configure API Mediation layer
# TODO - ALTERS INSTALLED PRODUCT
_cmd $scripts/zowe-configure-api-mediation.sh

# Configure the zLUX server, run last to make possible warning stand out
# TODO - ALTERS INSTALLED PRODUCT
_cmd $scripts/zowe-configure-zlux.sh

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

echo "-------------------------------"
echo "Follow the instructions in the Zowe Customization Guide to \
  complete the additional activation tasks:"

echo "- security definitions"
echo "- system PROCLIB updates"
echo "- system PARMLIB updates"
echo
echo "You can start the Zowe servers once all tasks are completed."
# TODO - IN PROGRESS
#echo "To start Zowe run the script $scripts/zowe-start.sh"
#echo "   (or in SDSF directly issue the command /S $ZOWE_SERVER_PROCLIB_MEMBER)"
#echo "To stop Zowe run the script $scripts/zowe-stop.sh"
#echo "  (or in SDSF directly the command /C $ZOWE_SERVER_PROCLIB_MEMBER)"

# Save install log in runtime directory
# TODO - ALTERS INSTALLED PRODUCT
_cmd mkdir $ZOWE_ROOT_DIR/setup_log
_cmd cp $LOG_FILE $ZOWE_ROOT_DIR/setup_log
}    # _config

# ---------------------------------------------------------------------
# --- Add support for restart & restore of configuration
#
# During the first run of the configuration script, the 
# restart-incomplete flag is set. This indicates to all sub-scripts 
# that they have to take a (restart) backup before customizing a file 
# (this saves original version of the file). Note that this backup does
# NOT iclude files merely copied, only the ones customized.
# The restart-incomplete flag remains set until the configuration
# script completes successfully.
# Each time the configuration script is run again, the original version
# of the files is restored so that the configuration tasks always have
# the same input, whether it is the first or the 20th run.
# If the configuration script has completed successfully before, then
# a (restore) backup is taken of the customized file before restoring
# the original version. This allows for a simple restore of the
# previous setup, for example in case the new one is broken.
#
# This function, and related services in the sub-scripts, can be 
# removed once customization no longer alters the isntalled product.
# ---------------------------------------------------------------------
function _backup
{
# Create infrastructure for restart & restore of configuration
_cmd mkdir -p $ZOWE_ROOT_DIR/backup/restart  # holds shipped version
_cmd mkdir -p $ZOWE_ROOT_DIR/backup/restore  # holds customized version

# Get list of files that were customized in a previous run
_cmd cd $ZOWE_ROOT_DIR/backup/restart
customized=$(find . -type f) 2>&1
test "$debug" && echo "$(echo $customized | wc -c) chars in \$customized"
_cmd --null cd -

# No previous run that failed ?
if test ! -f $ZOWE_ROOT_DIR/backup/restart-incomplete
then     # very first config run or previous run completed successfully
  # If this script completed in the past then it created a restart
  # backup of the customized files, which is documented in $customized.
  # We use that list to take a backup of the customized version of the
  # files for restore purposes (see zowe-configure-RESTORE.sh).
  # $customized is empty on the first run of this script.
  # The restore-incomplete flag is used to indicate failure during the
  # backup process.
  _cmd touch $ZOWE_ROOT_DIR/backup/restore-incomplete
  _cmd cd $ZOWE_ROOT_DIR/backup/restore
  for file in $customized
  do
    _cmd mkdir -p $(dirname $file)
    _cmd cp -f $ZOWE_ROOT_DIR/$file $file
  done    # for file
  _cmd --null cd -
  _cmd rm -f $ZOWE_ROOT_DIR/backup/restore-incomplete
fi    # take backup of active configuration

# If this script ran in the past (success or failure), then it created
# a restart backup of the customized files, which is documented in
# $customized. We use that list to reset these files back to their
# original state so this run can customize them.
_cmd cd $ZOWE_ROOT_DIR/backup/restart
for file in $customized
do
  _cmd cp -f $file $ZOWE_ROOT_DIR/$file
done    # for file
_cmd --null cd -

# Set a flag to indicate that this customization run did not yet
# complete successfully. At the end of this script, the marker is
# removed, indicating that the restart backup is complete.
# This flag is only set for the first run.
test -z "$customized" && _cmd touch $ZOWE_ROOT_DIR/backup/restart-incomplete
}    # _backup

# ---------------------------------------------------------------------
# --- ensure things are good to start configuration
# ---------------------------------------------------------------------
function _verify
{
# Test for configuring something else as current install
if test "$INSTALL_DIR" != "$ZOWE_ROOT_DIR"
then
  echo "** ERROR $me target directory $ZOWE_ROOT_DIR does not match" \
    "script home directory $INSTALL_DIR" | tee -a $LOG_FILE
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# Test for missing/incorrect installation - USS
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
    echo "** ERROR $me $ZOWE_ROOT_DIR holds Zowe $target_version and" \
      "this script is expecting Zowe $ZOWE_VERSION" | tee -a $LOG_FILE
    echo "   Please install Zowe $ZOWE_VERSION first, or correct" \
      "$ZOWE_CFG before attempting the configuration."
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
else                                          # manifest does not exist
  echo "** ERROR $me $ZOWE_ROOT_DIR does not hold Zowe" | tee -a $LOG_FILE
  echo "   Please install Zowe $ZOWE_VERSION first, or correct" \
    "$ZOWE_CFG before attempting the configuration."
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    # missing/incorrect Zowe in USS

# Test for missing installation - MVS
_verifyMVS "${ZOWE_HLQ}.SZWEAUTH"
_verifyMVS "${ZOWE_HLQ}.SZWESAMP"

# Verify that Node is available
if test ! -d "$NODE_HOME"
then
  echo "** ERROR $me NODE_HOME specified in $ZOWE_CFG is not valid" \
    | tee -a $LOG_FILE
  echo "ls -l \"$NODE_HOME/\""; ls -l "$NODE_HOME/"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

node="$NODE_HOME/bin/node"
if test ! -x $node
then
  echo "** ERROR $me cannot execute '$node'" | tee -a $LOG_FILE
  echo "ls -ld \"$node\""; ls -ld "$node"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# Test for update permission to product libraries
# TODO - ALTERS INSTALLED PRODUCT
_cmd touch $ZOWE_ROOT_DIR/$$
_cmd rm -f $ZOWE_ROOT_DIR/$$
}    # _verify

# ---------------------------------------------------------------------
# --- Verify existance of a data set
# $1: data set name mask
# ---------------------------------------------------------------------
function _verifyMVS
{
# Show everything in debug mode
test "$debug" && $scripts/get-dsn.rex -d "$1"
# Get data set list (no debug mode to avoid debug messages)
datasets=$($scripts/get-dsn.rex "$1")
# returns 0 for match, 1 for no match, 8 for error
rc=$?
if test $rc -eq 1
then
  echo "** ERROR $me $ZOWE_HLQ does not hold Zowe data sets" \
    | tee -a $LOG_FILE
  echo "   Please install Zowe $ZOWE_VERSION first, or correct" \
    "$ZOWE_CFG before attempting the configuration."
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
elif test $rc -gt 1
then
  echo "$datasets"                       # variable holds error message
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _verifyMVS

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
test "$ExEc" && _cmd chmod a+x ${2:-$1}         # make executable
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
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing
export _EDC_ADD_ERRNO2=1                        # show details on error
# .profile with ENV=script with echo -> echo is in stdout (begin)
unset ENV
_cmd umask 0022                                  # similar to chmod 755

echo
echo "-- $me -- $(sysvar SYSNAME) -- $(date)"
echo "-- startup arguments: $@"

# Clear input variables
unset LOG_FILE LOG_DIR ZOWE_CFG ZOWE_ROOT_DIR
# do NOT unset debug TMPDIR
# always unset ZOWE_ROOT_DIR

# Get startup arguments
while getopts c:f:l:t:d? opt
do case "$opt" in
  c)   export ZOWE_CFG="$OPTARG";;
  d)   export debug="-d";;
  f)   export LOG_FILE="$OPTARG";;
  l)   export LOG_DIR="$OPTARG";;
  t)   export TMPDIR="$OPTARG";;
  [?]) _displayUsage
       test $opt = '?' || echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

# No install, only configuration (used by zowe-set-envvars.sh)
unset inst
conf=1

# Set all required environment variables & logging
# zowe-set-envvars.sh exports environment vars, so run in current shell
_cmd . $(dirname $0)/../scripts/zowe-set-envvars.sh

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

echo "-- Beginning configuration of Zowe $ZOWE_VERSION using $ZOWE_CFG"
# LOG_FILE is already updated by zowe-set-envvars.sh

# Ensure things are good to start configuration
_verify

# Create infrastructure for restart & restore of configuration
_backup

# Configure Zowe
_config

# Indicate we have a successfull run, which implies all shipped files
# that were customized are backed up. This allows for a restart of the
# configuration script with different values.
_cmd rm -f $ZOWE_ROOT_DIR/backup/restart-incomplete

echo "-- Completed configuration of Zowe $ZOWE_VERSION using $ZOWE_CFG"
echo "Configuration completed -- $(date)" >> $LOG_FILE
test "$debug" && echo && echo "< $me 0"
exit 0
