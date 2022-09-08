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

if [ -z "${ZWE_zowe_runtimeDirectory}" ]; then
  >&2 echo "Error ZWEL0101E: ZWE_zowe_runtimeDirectory is not defined."
  exit 101
fi

export ZWE_PRIVATE_DS_SZWEAUTH=SZWEAUTH
export ZWE_PRIVATE_DS_SZWEPLUG=ZWESAPL
export ZWE_PRIVATE_DS_SZWESAMP=SZWESAMP
export ZWE_PRIVATE_DS_SZWEEXEC=SZWEEXEC
export ZWE_PRIVATE_DS_SZWELOAD=SZWELOAD
export ZWE_PRIVATE_DEFAULT_ADMIN_GROUP=ZWEADMIN
export ZWE_PRIVATE_DEFAULT_ZOWE_USER=ZWESVUSR
export ZWE_PRIVATE_DEFAULT_ZIS_USER=ZWESIUSR
export ZWE_PRIVATE_DEFAULT_ZOWE_STC=ZWESLSTC
export ZWE_PRIVATE_DEFAULT_ZIS_STC=ZWESISTC
export ZWE_PRIVATE_DEFAULT_AUX_STC=ZWESASTC
export ZWE_PRIVATE_CORE_COMPONENTS_REQUIRE_JAVA=gateway,cloud-gateway,discovery,api-catalog,caching-service,metrics-service,files-api,jobs-api

. "${ZWE_zowe_runtimeDirectory}/bin/libs/certificate.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/container.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/common.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/component.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/config.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/fs.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/java.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/json.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/logging.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/network.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/node.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/string.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/sys.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/var.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/zos.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/zos-dataset.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/zos-fs.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/zos-jes.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/zosmf.sh"
. "${ZWE_zowe_runtimeDirectory}/bin/libs/zwecli.sh"

export ZWE_PRIVATE_CLI_LIBRARY_LOADED=true
