/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

import {
  checkMandatoryEnvironmentVariables,
  installAndVerifyConvenienceBuild,
  showZoweRuntimeLogs,
} from '../../../../utils';
import { TEST_TIMEOUT_CONVENIENCE_BUILD } from '../../../../constants';

/**
 * Define this test should run in a specific worker
 *
 * @worker marist-3
 */
// hard code to use marist-3 which we started with Top Secret
const testServer = 'marist-3';
const testSuiteName = 'Test convenience build installation with Top Secret';
describe(testSuiteName, () => {
  beforeAll(() => {
    // validate variables
    checkMandatoryEnvironmentVariables([
      'ZOWE_BUILD_LOCAL',
    ]);
  });

  test('install and verify', async () => {
    await installAndVerifyConvenienceBuild(
      testSuiteName,
      testServer,
      {
        'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
      }
    );
  }, TEST_TIMEOUT_CONVENIENCE_BUILD);

  afterAll(async () => {
    await showZoweRuntimeLogs(testServer);
  })
});
