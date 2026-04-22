/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/
import * as std from 'cm_std';
import * as index from './index';

// Resolve parameters from the environment variables set by the zwe CLI framework.
// Parameter name `foo-bar` maps to env var ZWE_CLI_PARAMETER_FOO_BAR.
const userId: string | undefined = std.getenv('ZWE_CLI_PARAMETER_USER_ID') || undefined;
const minAssizemaxRaw: string | undefined = std.getenv('ZWE_CLI_PARAMETER_MIN_ASSIZEMAX') || undefined;
const minUlimitARaw: string | undefined = std.getenv('ZWE_CLI_PARAMETER_MIN_ULIMIT_ADDRESS_SPACE') || undefined;
const minTsoSizeRaw: string | undefined = std.getenv('ZWE_CLI_PARAMETER_MIN_TSO_SIZE') || undefined;
const minMemlimit: string | undefined = std.getenv('ZWE_CLI_PARAMETER_MIN_MEMLIMIT') || undefined;

// Convert numeric strings to numbers where applicable.
const minUlimitA: number | undefined = minUlimitARaw ? parseInt(minUlimitARaw, 10) : undefined;
const minTsoSize: number | undefined = minTsoSizeRaw ? parseInt(minTsoSizeRaw, 10) : undefined;

// Execute the memory validation and exit with the failure count (0 = success).
const failedCount = index.execute(userId, minAssizemaxRaw, minUlimitA, minTsoSize, minMemlimit);
if (failedCount > 0) {
  std.exit(failedCount);
}
