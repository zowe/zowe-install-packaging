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
  installAndVerifySmpeFmid,
  showZoweRuntimeLogs,
} from '../../../../utils';
import {TEST_TIMEOUT_SMPE_FMID} from '../../../../constants';

/**
 * Define this test should run in a specific worker
 *
 * @worker marist-4
 */
const testServer = 'marist-4';
const testSuiteName = 'Test SMPE FMID installation with RACF';
describe(testSuiteName, () => {
  beforeAll(() => {
    // validate variables
    checkMandatoryEnvironmentVariables([
      'ZOWE_BUILD_LOCAL',
    ]);
  });

  test('install and verify', async () => {
    await installAndVerifySmpeFmid(
      testSuiteName,
      testServer,
      {
        'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
        'zowe_lock_keystore': 'false',
      }
    );
  }, TEST_TIMEOUT_SMPE_FMID);

  afterAll(async () => {
    await showZoweRuntimeLogs(testServer);
  })
});
