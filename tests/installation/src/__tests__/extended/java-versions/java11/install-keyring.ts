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
  import {
    TEST_TIMEOUT_CONVENIENCE_BUILD,
    KEYSTORE_MODE_KEYRING,
  } from '../../../../constants';
  
  const testServer = process.env.TEST_SERVER;
  const testSuiteName = 'Test convenience build installation by enabling VERIFY_CERTIFICATES with java 11';
  describe(testSuiteName, () => {
    beforeAll(() => {
      // validate variables
      checkMandatoryEnvironmentVariables([
        'TEST_SERVER',
        'ZOWE_BUILD_LOCAL',
      ]);
    });
  
    test('install and verify', async () => {
      await installAndVerifyConvenienceBuild(
        testSuiteName,
        testServer,
        {
          'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
          'zowe_custom_for_test': 'true',
          'zos_keystore_mode': KEYSTORE_MODE_KEYRING,
          'zos_java_home': '/ZOWE/node/J11.0_64',
          'zowe_lock_keystore': 'false',
        }
      );
    }, TEST_TIMEOUT_CONVENIENCE_BUILD);
  
    afterAll(async () => {
      await showZoweRuntimeLogs(testServer);
    })
  });
  