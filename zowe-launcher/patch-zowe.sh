#!/bin/sh

################################################################################
#  This program and the accompanying materials are
#  made available under the terms of the Eclipse Public License v2.0 which accompanies
#  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
#
#  SPDX-License-Identifier: EPL-2.0
#
#  Copyright Contributors to the Zowe Project.
################################################################################

set -eu

. zowe.conf

cd ./patches

patch -i instance.patch $ZOWE_INSTANCE_DIR/instance.env
patch -i zowe-start.patch $ZOWE_INSTANCE_DIR/bin/zowe-start.sh
patch -i run-zowe.patch $ZOWE_INSTALL_DIR/bin/internal/run-zowe.sh
patch -i api-mediation_start.patch $ZOWE_INSTALL_DIR/components/api-mediation/bin/start.sh
patch -i explorer-jes_start.patch $ZOWE_INSTALL_DIR/components/explorer-jes/bin/start.sh
patch -i explorer-mvs_start.patch $ZOWE_INSTALL_DIR/components/explorer-mvs/bin/start.sh
patch -i explorer-uss_start.patch $ZOWE_INSTALL_DIR/components/explorer-uss/bin/start.sh
patch -i files-api_start.patch $ZOWE_INSTALL_DIR/components/files-api/bin/start.sh
patch -i jobs-api_start.patch $ZOWE_INSTALL_DIR/components/jobs-api/bin/start.sh
