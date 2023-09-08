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
  import {TEST_TIMEOUT_CONVENIENCE_BUILD} from '../../../../constants';
  
  const testSuiteName = 'Test convenience build installation with java 11';
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
        process.env.TEST_SERVER,
        {
          'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
          'zowe_custom_for_test': 'true',
          'zos_java_home': '/ZOWE/node/J11.0_64',
          'zowe_lock_keystore': 'false',
        }
      );
    }, TEST_TIMEOUT_CONVENIENCE_BUILD);
  
    afterAll(async () => {
      await showZoweRuntimeLogs(process.env.TEST_SERVER);
    })
  });
  