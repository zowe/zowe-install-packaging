#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2019, [YEAR]
#######################################################################

# Zowe Open Source project
# Dynamically create additional directories during SMP/E APPLY
# (only active with Action COPY, Phase PRE)
#
# MCS definition for part:
# ++SHELLSCR(ZWESHMKD) SYSLIB(SZWEZFS ) DISTLIB(AZWEZFS ) RELFILE(4)
#   TEXT               PARM(PATHMODE(0,7,5,5)) .
#
# MCS definition for usage:
# ++HFS(...) SHSCRIPT(ZWESHMKD,PRE) ...
#
# SMP/E will set these environment variables for the script to use
#
#   SMP_File      - name of the SMP/E file that triggered the script
#                   invocation
#   SMP_Directory - directory in which the SMP/E file resides
#   SMP_Action    - the action that SMP/E is performing: COPY or DELETE
#   SMP_Phase     - indicates if the shell script is called before or
#                   after SMP/E has processed the file: PRE or POST
#                   action=DELETE -> Phase=PRE (always)
#                   action=COPY   -> Phase=POST by default
#
# SMP/E expects a retun code
#
#   0             - all is OK
#   anything else - error, SMP/E processing will fail
#
# ---------------------------------------------------------------------

IgNoRe_ErRoR=                  # if not null, then do not exit on error
_dirs=''         # directory names include path based on $SMP_Directory
_dirs='../sample_placeholder'

echo "Start script processing..." $0
_status=0                                    # script status, must be 0

# enable detailed error messages
_EDC_ADD_ERRNO2=1

# display general statistics
echo
whence $0
echo $(sysvar SYSNAME) -- $(date) UTC
id
echo

echo "* Input environment variables"
echo
echo "SMP_Directory=$SMP_Directory"
echo "SMP_File     =$SMP_File"
echo "SMP_Phase    =$SMP_Phase"
echo "SMP_Action   =$SMP_Action"

#
# verify that the required input was received by the shell script
#
if test ! "$SMP_Directory"
then
  echo "** ERROR No SMP_Directory parameter specified."
  _status=-1
elif test ! "$SMP_File"
then
  echo "** ERROR No SMP_File parameter specified."
  _status=-1
elif test ! "$SMP_Phase"
then
  echo "** ERROR No SMP_Phase parameter specified."
  _status=-1
elif test ! "$SMP_Action"
then
  echo "** ERROR No SMP_Action parameter specified."
  _status=-1
fi
if test $_status -ne 0      # if status is not 0, an error was detected
then
  echo " If SMP/E was not used to invoke the script, correct the"
  echo " caller to specify the input environment variables."
  echo " If SMP/E invoked this script, contact the IBM support center."
  echo "** Exiting script with status $_status"
  echo
  test "$IgNoRe_ErRoR" || exit $status                           # EXIT
fi

#
# only active with Action COPY, Phase PRE
#
if test "$SMP_Action" = "COPY" -a "$SMP_Phase" = "PRE"
then
  #
  # go to the work directory
  #
  cd $SMP_Directory 2>&1
  _status=$?
  if test $_status -ne 0
  then
    echo "** ERROR cd $SMP_Directory ended with status $_status"
    echo "** Exiting script with status $_status"
    echo
    test "$IgNoRe_ErRoR" || exit $status                         # EXIT
  fi

  #
  # set mask for creating 755 directories
  #
  umask 022 2>&1
  _status=$?
  if test $_status -ne 0
  then
    echo "** ERROR umask 022 ended with status $_status"
    echo "** Exiting script with status $_status"
    echo
    test "$IgNoRe_ErRoR" || exit $status                         # EXIT
  fi

  #
  # create new directories (-p gives rc 0 when directory exists)
  #
  mkdir -p $_dirs 2>&1
  _status=$?
  if test $_status -ne 0
  then
    echo "** ERROR mkdir -p $_dirs ended with status $_status"
    echo "** Exiting script with status $_status"
    echo
    test "$IgNoRe_ErRoR" || exit $status                         # EXIT
  fi
else
  echo "* Nothing done, wrong Action/Phase"
fi

echo
echo "* Exiting script with status $_status"
echo
exit $_status                                      # =0: ok, <>0: error
