/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as os from 'os';

if (!std.getenv("ZWE_zowe_runtimeDirectory")) {
  std.err.printf("Error ZWEL0101E: ZWE_zowe_runtimeDirectory is not defined.\n");
  std.exit(101);
}

std.setenv('ZWE_PRIVATE_DS_SZWEAUTH', 'SZWEAUTH');
std.setenv('ZWE_PRIVATE_DS_SZWEPLUG', 'SZWEPLUG');
std.setenv('ZWE_PRIVATE_DS_SZWESAMP', 'SZWESAMP');
std.setenv('ZWE_PRIVATE_DS_SZWEEXEC', 'SZWEEXEC');
std.setenv('ZWE_PRIVATE_DEFAULT_ADMIN_GROUP', 'ZWEADMIN');
std.setenv('ZWE_PRIVATE_DEFAULT_ZOWE_USER', 'ZWESVUSR');
std.setenv('ZWE_PRIVATE_DEFAULT_ZIS_USER', 'ZWESIUSR');
std.setenv('ZWE_PRIVATE_DEFAULT_ZOWE_STC', 'ZWESLSTC');
std.setenv('ZWE_PRIVATE_DEFAULT_ZIS_STC', 'ZWESISTC');
std.setenv('ZWE_PRIVATE_DEFAULT_AUX_STC', 'ZWESASTC');
std.setenv('ZWE_PRIVATE_CORE_COMPONENTS_REQUIRE_JAVA', 'gateway,discovery,api-catalog,caching-service,metrics-service,files-api,jobs-api');

std.setenv('ZWE_PRIVATE_CLI_LIBRARY_LOADED', 'true');
