#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2020, 2020
#######################################################################

# Expected globals:
# $INSTALL_ERROR
# $LOG_FILE
# $TEMP_DIR
# $debug
# $script
# $touchIt

# source this file in install scripts
# . ${INSTALL_DIR}/scripts/zowe-install-utils.sh

# ---------------------------------------------------------------------
function _scriptStart {
# $1: script name

origScript=${script}
origDir=$(pwd)
script=$1
echo "" >> ${LOG_FILE}
echo "<$script>" >> ${LOG_FILE}
echo "  $(date) in progress ... " | tee -a ${LOG_FILE}
}    # _scriptStart

# ---------------------------------------------------------------------
function _scriptStop {
echo "</$script>" >> ${LOG_FILE}
echo "" >> ${LOG_FILE}
cd ${origDir}
script=${origScript}
}    # _scriptStop

# ---------------------------------------------------------------------
function _setInstallError {
export INSTALL_ERROR=true                     # mark error but continue
## uncomment next lines to fail on first error
## comment next lines to continue on error but fail script
#echo "  Installation terminated" | tee -a ${LOG_FILE}
#exit 1
}    # _setInstallError

# ---------------------------------------------------------------------
function _cmd {  # arbitrary command
# $@: command and arguments

echo "$@" 1>>${LOG_FILE}
"$@" 1>>${LOG_FILE} 2>&1            # stdout/stderr only in ${LOG_FILE}
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "Error: $script '$@' ended with RC $sTaTuS" | tee -a ${LOG_FILE}
  _setInstallError
fi    #

test $sTaTuS -eq 0                                    # set return code
}    # _cmd

# ---------------------------------------------------------------------
function _pax {  # unpax
# $1: pax file
# $@: (optional) pattern

pAxFiLe=$1
shift
# explode pax
# pax
#  -f "$pAxFiLe"  pax file
#  -ppx           preserve file mode and extended attributes
#                 * file mode: access permissions (skipping umask),
#                   set-user-ID bit, set-group-ID bit, and sticky bit
#                 * extended attributes: APF-authorized, shared library,
#                   program-controlled, shared address space
#  -r             read (extract)
#  -v             verbose
oPt="-rf $pAxFiLe -ppx $@"
test -n "${debug}" && oPt=$(echo $oPt | sed '#^-#-v#')    # add verbose

echo "pax $oPt" 1>>${LOG_FILE}
pax $oPt 1>>${LOG_FILE} 2>&1        # stdout/stderr only in ${LOG_FILE}
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "Error: $script 'pax $oPt' ended with RC $sTaTuS" | tee -a ${LOG_FILE}
  _setInstallError
fi    #

# track usage
if test -n "${touchIt}"
then
  _cmd touch $pAxFiLe 1>>${LOG_FILE} 2>&1                 # track usage
fi    #

test $sTaTuS -eq 0                                    # set return code
}    # _pax

# ---------------------------------------------------------------------
function _cp {  # copy
# $@: from [from ...] to

# cp
#  -f  force
#  -v  verbose
oPt="-f $@"
test -n "${debug}" && oPt=$(echo $oPt | sed '#^-#-v#')    # add verbose

echo "cp $oPt" 1>>${LOG_FILE}
cp $oPt 1>>${LOG_FILE} 2>&1         # stdout/stderr only in ${LOG_FILE}
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "Error: $script 'cp $oPt' ended with RC $sTaTuS" | tee -a ${LOG_FILE}
  _setInstallError
fi    #

# track usage
if test -n "${touchIt}"
then
  # remove additional command options
  while test "$(echo $1 | cut -c1)" = "-"
  do
    shift
  done    # while "-"
  _cmd touch $@ 1>>${LOG_FILE} 2>&1                       # track usage
fi    #

test $sTaTuS -eq 0                                    # set return code
}    # _cp

# ---------------------------------------------------------------------
function _cpr {   # recursive copy
# $@: from [from ...] to

# cp
#  -f  force
#  -r  recursive
#  -v  verbose
oPt="-vrf $@"                                          # always verbose

tEmPfIlE=${TEMP_DIR}/_cpr.$RANDOM
echo "cp $oPt" 1>>${LOG_FILE}
cp $oPt 1>>${tEmPfIlE} 2>&1         # stdout/stderr only in ${tEmPfIlE}
sTaTuS=$?
cat ${tEmPfIlE} 1>>${LOG_FILE}             # save output in ${LOG_FILE}
if test $sTaTuS -ne 0
then
  echo "Error: $script 'cp $oPt' ended with RC $sTaTuS" | tee -a ${LOG_FILE}
  _setInstallError
fi    #

# track usage
if test -n "${touchIt}"
then
  # cp -v writes "from -> to" per file to stdout
  for tOtOuCh in $(awk '/ -> /{print $1}' ${tEmPfIlE})
  do
    _cmd touch ${tOtOuCh} 1>>${LOG_FILE} 2>&1             # track usage
  done
fi    #

rm -f ${tEmPfIlE}

test $sTaTuS -eq 0                                    # set return code
}    # _cpr

