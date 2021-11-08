#!/bin/sh

#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

if [ -z "${ZOWE_RUNTIME_DIRECTORY}" ]; then
  >&2 echo "Error: ZOWE_RUNTIME_DIRECTORY is not defined"
  exit 1
fi

. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/fs.sh"
. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/http.sh"
. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/java.sh"
. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/json.sh"
. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/logging.sh"
. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/network.sh"
. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/node.sh"
. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/string.sh"
. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/sys.sh"
. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/var.sh"
. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/zosmf.sh"
. "${ZOWE_RUNTIME_DIRECTORY}/bin/libs/zwecli.sh"
