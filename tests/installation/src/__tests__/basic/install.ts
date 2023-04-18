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
} from '../../utils';
import {TEST_TIMEOUT_CONVENIENCE_BUILD} from '../../constants';

const testSuiteName = 'Test convenience build installation';
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
        'zowe_apiml_security_oidc_client_id': process.env['OKTA_CLIENT_ID'],
        'zowe_apiml_security_oidc_client_secret': process.env['OKTA_CLIENT_SECRET'],
        'zowe_apiml_security_oidc_registry': process.env['OIDC_REGISTRY'],
        'zowe_apiml_security_oidc_introspect_url': `https://${process.env['OKTA_HOSTNAME']}/oauth2/default/v1/introspect`,
        'zowe_custom_for_test': 'true',
        'zowe_lock_keystore': 'false',
      }
    );
  }, TEST_TIMEOUT_CONVENIENCE_BUILD);

  afterAll(async () => {
    await showZoweRuntimeLogs(process.env.TEST_SERVER);
  })
});
