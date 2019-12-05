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

set -e
ZOWE_ROOT_DIR={{root_dir}}
ZOWE_ZOSMF_ADMIN_GROUP={{zosmf_admin_group}}
LOG_FILE={{configure_log_file}}

echo "<zowe-runtime-authorize.sh>" >> $LOG_FILE

# This is from the zLUX install
if extattr ${ZOWE_ROOT_DIR}/zlux-app-server/bin/zssServer | grep "Program controlled = NO"; then
  echo "zssServer does not have the proper extattr values"
  echo "   Please run extattr +p $PWD/zlux-app-server/bin/zssServer"
  exit 1
fi

#Give all directories -rw+x permission so they can be listed, but files -rwx
chmod -R o-rwx ${ZOWE_ROOT_DIR}
echo "  About to run find and chmods to add o+x on directories" >> $LOG_FILE
find ${ZOWE_ROOT_DIR} -type d -exec chmod o+x {} \; 2>/dev/null
echo "  Completed find and chmods to add o+x on directories" >> $LOG_FILE

#TODO SH: temporary fix whilst logs are't in the user-dir.
chmod -R g+w ${ZOWE_ROOT_DIR}/zlux-app-server/log

# If this step fails it is because the user running this script is not part of the IZUADMIN group
chgrp -R ${ZOWE_ZOSMF_ADMIN_GROUP} ${ZOWE_ROOT_DIR}


chmod -R 770 ${ZOWE_ROOT_DIR}/zlux-app-server/deploy
chmod -R 550 ${ZOWE_ROOT_DIR}/zlux-app-server/deploy/product
# For Zowe to come up the ZWESVSTC STC needs read access to ../deploy/instance/ZLUX/serverConfig/zluxServer.json
chmod -R g-w ${ZOWE_ROOT_DIR}/zlux-app-server/deploy/instance/ZLUX/serverConfig
chmod -R g-w ${ZOWE_ROOT_DIR}/zlux-app-server/deploy/site/ZLUX/serverConfig
if [ "$(ls -A ${ZOWE_ROOT_DIR}/zlux-app-server/deploy/instance/ZLUX/serverConfig)" ]; then
  chmod -R g-x ${ZOWE_ROOT_DIR}/zlux-app-server/deploy/instance/ZLUX/serverConfig/*
fi
if [ "$(ls -A ${ZOWE_ROOT_DIR}/zlux-app-server/deploy/site/ZLUX/serverConfig)" ]; then
  chmod -R g-x ${ZOWE_ROOT_DIR}/zlux-app-server/deploy/site/ZLUX/serverConfig/*
fi
echo "</zowe-runtime-authorize.sh>" >> $LOG_FILE