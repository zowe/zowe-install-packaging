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
} from '../../../utils';
import {
  TEST_TIMEOUT_CONVENIENCE_BUILD,
} from '../../../constants';

const testServer = process.env.TEST_SERVER;
const testSuiteName = 'Test convenience build installation by using external certificate';
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
        'zowe_custom_for_test': true,
        'zowe_apiml_verify_certficates_of_services': true,
        'zowe_apiml_nonstrict_verify_certficates_of_services': true,
        'zowe_external_certficate': '/ZOWE/extcerts/dummy_certs.keystore.p12',
        'zowe_external_certficate_alias': 'dummy_certs',
        'zowe_external_certficate_authorities': '/ZOWE/extcerts/dummy_ca.cer',
        'zowe_keystore_password': 'dummycert',
      }
    );
  }, TEST_TIMEOUT_CONVENIENCE_BUILD);

  afterAll(async () => {
    await showZoweRuntimeLogs(testServer);
  })
});
