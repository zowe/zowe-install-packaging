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
} from '../../../utils';
import { TEST_TIMEOUT_SMPE_FMID, TEST_TIMEOUT_SMPE_PTF } from '../../../constants';

const testSuiteName = 'Test 3.0 base install then upgrade (basic config)';
describe(testSuiteName, () => {
  beforeAll(() => {
    // validate variables
    checkMandatoryEnvironmentVariables([
      'TEST_SERVER',
      'ZOWE_BUILD_LOCAL',
    ]);
  });

  test('install and verify', async () => {
    await installAndVerifySmpePtf(
      testSuiteName,
      process.env.TEST_SERVER,
      {
        'zowe_custom_for_test': 'true'
      },
      {
        'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
        'zowe_custom_for_test': false,
        'zowe_ptf_configure': false,
        'zowe_lock_keystore': 'false',
      }
    );
  }, TEST_TIMEOUT_SMPE_FMID + TEST_TIMEOUT_SMPE_PTF); // long timeout since we start + test both
    

  afterAll(async () => {
    await showZoweRuntimeLogs(process.env.TEST_SERVER);
  });

});
