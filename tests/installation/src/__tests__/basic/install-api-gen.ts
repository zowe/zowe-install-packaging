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
  installAndGenerateApiDocs,
} from '../../utils';
import { TEST_TIMEOUT_CONVENIENCE_BUILD } from '../../constants';
  
const testSuiteName = 'Test convenience build installation';
describe(testSuiteName, () => {
  beforeAll(() => {
    // validate variables
    checkMandatoryEnvironmentVariables([
      'TEST_SERVER',
      'ZOWE_BUILD_LOCAL',
    ]);
  });
  
  test('install and generate api documentation', async () => {
    await installAndGenerateApiDocs(
      testSuiteName,
      process.env.TEST_SERVER,
      {
        'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
        'zowe_lock_keystore': 'false',
      }
    );
  }, TEST_TIMEOUT_CONVENIENCE_BUILD);
});
