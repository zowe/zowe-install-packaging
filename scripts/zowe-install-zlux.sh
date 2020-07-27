#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2018, 2020
#######################################################################

# Expected globals:
# $ZOWE_ROOT_DIR
# $INSTALL_DIR
# $LOG_FILE

# NOTE FOR DEVELOPMENT
# Use functions _cp/_cpr/_pax to copy/recursive copy/unpax from 
# ${INSTALL_DIR}, as these will mark the source as processed. The build 
# pipeline will verify that all ${INSTALL_DIR} files are processed.
# Use function _cmd to add standard error handling to command execution.
# Use function _setInstallError in custom error handling.

# Note: zowe-install.sh does "chmod 755" for all

#% caller needs these RACF permits, or ACF2/TSS equivalent:
#% TSO PE BPX.FILEATTR.PROGCTL CL(FACILITY) ACCESS(READ) ID(userid)
#% TSO SETR RACLIST(FACILITY) REFRESH

_scriptStart zowe-install-zlux.sh
#umask 0002

cd $INSTALL_DIR

# APP SERVER

unset ZLUX_APP_SERVER_ROOT
APP_SERVER_ROOT=${ZOWE_ROOT_DIR}/components/app-server
INSTALL_FOLDER=${INSTALL_DIR}/files/zlux
echo "  Installing App Server into ${APP_SERVER_ROOT} ..." >> ${LOG_FILE}
_cmd mkdir -p ${APP_SERVER_ROOT}/bin \
              ${APP_SERVER_ROOT}/share

# unpax archives if mkdir successful
if test $? -eq 0 ; then
  cd ${APP_SERVER_ROOT}/share

  for paxFile in ${INSTALL_FOLDER}/*.pax ; do
    if test "${paxFile}" = "${INSTALL_FOLDER}/zlux-core.pax" ; then
      echo "  Unpax of ${paxFile} into ${PWD}" >> ${LOG_FILE}
      _pax ${paxFile}
    else
      fileName=$(basename $paxFile)
      pluginName=${fileName%.*}         # keep until last . (exclusive)
      _cmd mkdir ${pluginName}
      
      # unpax archive if mkdir successful
      if test $? -eq 0 ; then
        cd ${pluginName}
        echo "  Unpax of ${paxFile} into ${PWD}" >> ${LOG_FILE}
        _pax ${paxFile}
        cd ..
      fi    # target dir created
    fi    # unpax plugin
  done    # for paxFile

  # zlux-app-server is currently extracted from zlux-core.pax
  ZLUX_APP_SERVER_ROOT=${PWD}/zlux-app-server
  _cmd cp ${ZLUX_APP_SERVER_ROOT}/bin/start.sh \
          ${ZLUX_APP_SERVER_ROOT}/bin/configure.sh \
          ${APP_SERVER_ROOT}/bin/
        
  # TODO update build pipeline to set & preserve tags
  echo "  Update App Server file tags" >> ${LOG_FILE}
  targetDir=zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.ng2desktop/ui/launchbar/plugins
  _cmd mkdir -p ${targetDir}
  _cp ${INSTALL_FOLDER}/config/pinnedPlugins.json  ${targetDir}/
  _cmd chtag -tc 1047 ${targetDir}/pinnedPlugins.json

  targetDir=zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.bootstrap/plugins
  _cmd mkdir -p ${targetDir}
  _cp ${INSTALL_FOLDER}/config/allowedPlugins.json  ${targetDir}/
  _cmd chtag -tc 1047 ${targetDir}/allowedPlugins.json

  targetDir=zlux-app-server/defaults/serverConfig
  _cmd mkdir -p ${targetDir}
  _cp ${INSTALL_FOLDER}/config/zluxserver.json  ${targetDir}/server.json
  _cmd chtag -tc 1047 ${targetDir}/server.json
      
  targetDir=zlux-app-server/defaults/plugins
  _cmd mkdir -p ${targetDir}
  _cp ${INSTALL_FOLDER}/config/plugins/*  ${targetDir}/
  for json in $(ls ${INSTALL_FOLDER}/config/plugins/*) ; do
    _cmd chtag -tc 1047 ${targetDir}/$(basename ${json})
  done    # for json
    
  # ${INSTALL_DIR} can be read only
  #chtag -tc 1047 ${INSTALL_FOLDER}/config/*.json
  #chtag -tc 1047 ${INSTALL_FOLDER}/config/plugins/*.json

  # owner having write is set in build pipeline
  #chmod -R u+w zlux-app-server 2>/dev/null
fi    # APP SERVER dir created

# ZSS SERVER

ZSS_SERVER_ROOT=${ZOWE_ROOT_DIR}/components/zss
INSTALL_FOLDER=${INSTALL_DIR}/files
echo "  Installing ZSS Server into ${ZSS_SERVER_ROOT} ..." >> ${LOG_FILE}
_cmd mkdir -p ${ZSS_SERVER_ROOT}

# unpax archives if mkdir successful
if test $? -eq 0 ; then
  cd ${ZSS_SERVER_ROOT}

  echo "  Unpax of ${INSTALL_FOLDER}/zss.pax into ${PWD}" >> ${LOG_FILE}
  _pax ${INSTALL_FOLDER}/zss.pax  bin

  # additional tasks if unpax successful
  if test $? -eq 0 ; then
    echo "  Mark zssServer as program-controlled" >> ${LOG_FILE}
    _cmd ls -E bin/zssServer                # ensure this is set in pax
    # TODO remove? 
    _cmd extattr +p bin/zssServer              # safety net, set in pax

    # update APP SERVER
    if test -d "${ZLUX_APP_SERVER_ROOT}" ; then
      echo "  Update App Server with ZSS Server files" >> ${LOG_FILE}
      targetDir=${ZLUX_APP_SERVER_ROOT}/bin
      _cmd cp -vr ${ZSS_SERVER_ROOT}/bin/z*  ${targetDir}/

      if test $? -eq 0 ; then
        _cmd extattr +p ${targetDir}/zssServer
      fi    #  copy successful
    fi    # ${ZLUX_APP_SERVER_ROOT} exists
  fi    # unpax successful

  #chmod -R a-w tn3270-ng2/ vt-ng2/ zlux-app-manager/ zlux-app-server/ zlux-ng2/ zlux-server-framework/ zlux-shared/ 2>/dev/null
fi    # ZSS SERVER dir created

_scriptStop
