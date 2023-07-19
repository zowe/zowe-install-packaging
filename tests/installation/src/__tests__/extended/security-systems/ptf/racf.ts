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
  installAndVerifySmpePtf,
  showZoweRuntimeLogs,
} from '../../../../utils';
import {TEST_TIMEOUT_SMPE_PTF} from '../../../../constants';

/**
 * Define this test should run in a specific worker
 *
 * @worker marist-4
 */
const testServer = 'marist-4';
const testSuiteName = 'Test SMPE PTF installation with RACF';
describe(testSuiteName, () => {
  beforeAll(() => {
    // validate variables
    checkMandatoryEnvironmentVariables([
      'ZOWE_BUILD_LOCAL',
    ]);
  });

  test('install and verify', async () => {
    await installAndVerifySmpePtf(
      testSuiteName,
      testServer,
      {
        'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
        'zowe_custom_for_test': 'true',
        'zowe_lock_keystore': 'false',
      }
    );
  }, TEST_TIMEOUT_SMPE_PTF);

  afterAll(async () => {
    await showZoweRuntimeLogs(testServer);
  })
});
