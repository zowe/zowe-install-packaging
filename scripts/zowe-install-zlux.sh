#!/bin/sh
################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

#This file is for installing the pax file of zlux. It lives here so it is covered by source control. It is not called from this location

#********************************************************************
# Expected globals:
# $ZOWE_APIM_ENABLE_SSO
# $CONFIG_DIR
# $ZOWE_ROOT_DIR
# $TEMP_DIR

echo "<zowe-install-zlux.sh>" >> $LOG_FILE

umask 0002
APP_SERVER_COMPONENT_DIR=${ZOWE_ROOT_DIR}/components/app-server
ZSS_COMPONENT_DIR=${ZOWE_ROOT_DIR}/components/zss
mkdir -p ${APP_SERVER_COMPONENT_DIR}
mkdir -p ${ZSS_COMPONENT_DIR}
cd ${APP_SERVER_COMPONENT_DIR}
mkdir -p bin
mkdir -p share
cd share
echo "Unpax $INSTALL_DIR/files/zlux/zlux-core.pax " >> $LOG_FILE
pax -r -px -f $INSTALL_DIR/files/zlux/zlux-core.pax

for paxfile in ${INSTALL_DIR}/files/zlux/*.pax
do
  if [[ $paxfile != "${INSTALL_DIR}/files/zlux/zlux-core.pax" ]]
  then
    filename=$(basename $paxfile)
    pluginName="${filename%.*}"
    mkdir $pluginName && cd $pluginName
    echo "Unpax ${paxfile} " >> $LOG_FILE
    pax -r -px -f ${paxfile}
    cd ..
  fi
done

chtag -tc 1047 ${INSTALL_DIR}/files/zlux/config/*.json
chtag -tc 1047 ${INSTALL_DIR}/files/zlux/config/plugins/*.json
chmod -R u+w zlux-app-server 2>/dev/null
mkdir -p zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.ng2desktop/ui/launchbar/plugins
cp -f ${INSTALL_DIR}/files/zlux/config/pinnedPlugins.json zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.ng2desktop/ui/launchbar/plugins/
mkdir -p zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.bootstrap/plugins
cp -f ${INSTALL_DIR}/files/zlux/config/allowedPlugins.json zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.bootstrap/plugins/
cp -f ${INSTALL_DIR}/files/zlux/config/zluxserver.json zlux-app-server/defaults/serverConfig/server.json
cp -f ${INSTALL_DIR}/files/zlux/config/plugins/* zlux-app-server/defaults/plugins

echo "Unpax zssServer " >> $LOG_FILE
cd ${ZSS_COMPONENT_DIR}
pax -r -px -f $INSTALL_DIR/files/zss.pax bin
extattr +p bin/zssServer
cp -r ${ZSS_COMPONENT_DIR}/bin/z* ${APP_SERVER_COMPONENT_DIR}/share/zlux-app-server/bin
cd ${APP_SERVER_COMPONENT_DIR}/share

chmod -R a-w tn3270-ng2/ vt-ng2/ zlux-app-manager/ zlux-app-server/ zlux-ng2/ zlux-server-framework/ zlux-shared/ 2>/dev/null
cp zlux-app-server/bin/start.sh zlux-app-server/bin/configure.sh ${APP_SERVER_COMPONENT_DIR}/bin
chmod -R a-w zlux-app-server/ 2>/dev/null
cd $INSTALL_DIR
echo "</zowe-install-zlux.sh>" >> $LOG_FILE
