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
} from '../../utils';
import { TEST_TIMEOUT_SMPE_PTF } from '../../constants';

const testSuiteName = 'Test SMPE PTF installation';
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
        'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
      }
    );
  }, TEST_TIMEOUT_SMPE_PTF);
});
