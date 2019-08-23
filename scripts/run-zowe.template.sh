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

#
# Your JCL must invoke it like this:
#
# //        EXEC PGM=BPXBATSL,REGION=0M,TIME=NOLIMIT,
# //  PARM='PGM /bin/sh &SRVRPATH/scripts/internal/run-zowe.sh'
#
#
#export "NODE_PATH='"$ZOWE_ROOT_DIR"/zlux-app-server/bin':$NODE_PATH"

export ZOWE_PREFIX={{zowe_prefix}}{{zowe_instance}}
ZOWE_API_GW=${ZOWE_PREFIX}AG
ZOWE_API_DS=${ZOWE_PREFIX}AD
ZOWE_API_CT=${ZOWE_PREFIX}AC
ZOWE_DESKTOP=${ZOWE_PREFIX}DT
ZOWE_EXPL_JOBS=${ZOWE_PREFIX}EJ
ZOWE_EXPL_DATA=${ZOWE_PREFIX}ED
ZOWE_EXPL_UI_JES=${ZOWE_PREFIX}UJ
ZOWE_EXPL_UI_MVS=${ZOWE_PREFIX}UD
ZOWE_EXPL_UI_USS=${ZOWE_PREFIX}UU

if [[ ! -f $NODE_HOME/"./bin/node" ]]
then
export NODE_HOME={{node_home}}
fi

DIR=`dirname $0`

cd $DIR/../../zlux-app-server/bin && _BPX_JOBNAME=$ZOWE_DESKTOP ./nodeCluster.sh --allowInvalidTLSProxy=true &
_BPX_JOBNAME=$ZOWE_API_DS $DIR/../../api-mediation/scripts/api-mediation-start-discovery.sh
_BPX_JOBNAME=$ZOWE_API_CT $DIR/../../api-mediation/scripts/api-mediation-start-catalog.sh
_BPX_JOBNAME=$ZOWE_API_GW $DIR/../../api-mediation/scripts/api-mediation-start-gateway.sh
_BPX_JOBNAME=$ZOWE_EXPL_JOBS $DIR/../../explorer-jobs-api/scripts/jobs-api-server-start.sh
_BPX_JOBNAME=$ZOWE_EXPL_DATA $DIR/../../explorer-data-sets-api/scripts/data-sets-api-server-start.sh
_BPX_JOBNAME=$ZOWE_EXPL_UI_JES $DIR/../../jes_explorer/scripts/start-explorer-jes-ui-server.sh
_BPX_JOBNAME=$ZOWE_EXPL_UI_MVS $DIR/../../mvs_explorer/scripts/start-explorer-mvs-ui-server.sh
_BPX_JOBNAME=$ZOWE_EXPL_UI_USS $DIR/../../uss_explorer/scripts/start-explorer-uss-ui-server.sh
