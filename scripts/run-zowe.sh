#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

#
# Script to start node server and Atlas server.
#
#
# Your JCL must invoke it like this:
#
# //        EXEC PGM=BPXBATSL,REGION=0M,TIME=NOLIMIT,
# //  PARM='PGM /bin/sh &SRVRPATH/../scripts/internal/run-zowe.sh'
#
#
#export "NODE_PATH='"$ZOWE_ROOT_DIR"/zlux-app-server/bin':$NODE_PATH"
export NODE_HOME=$nodehome
`dirname $0`/../../zlux-app-server/bin/nodeServer.sh --allowInvalidTLSProxy=true &
`dirname $0`/../../api-mediation/scripts/api-mediation-start-discovery.sh
`dirname $0`/../../api-mediation/scripts/api-mediation-start-catalog.sh
`dirname $0`/../../api-mediation/scripts/api-mediation-start-gateway.sh
`dirname $0`/../../explorer-jobs-api/scripts/jobs-api-server-start.sh
`dirname $0`/../../explorer-data-sets-api/scripts/data-sets-api-server-start.sh
`dirname $0`/../../jes_explorer/scripts/start-explorer-jes-ui-server.sh
`dirname $0`/../../mvs_explorer/scripts/start-explorer-mvs-ui-server.sh
`dirname $0`/../../uss_explorer/scripts/start-explorer-uss-ui-server.sh
`dirname $0`/../../explorer-server/wlp/lib/native/zos/s390x/bbgzsrv Atlas
