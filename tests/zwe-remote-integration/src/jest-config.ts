/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

// only set retry when we're not updating snapshots...retries + updates causes problems with duplicate snapshots written out
if (!process.argv.includes('-u') && !process.argv.includes('--updateSnapshot')) {
  jest.retryTimes(1, { logErrorsBeforeRetry: true });
}
