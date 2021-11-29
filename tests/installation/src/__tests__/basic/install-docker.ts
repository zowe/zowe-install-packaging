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
  installAndVerifyDockerBuild,
  showZoweRuntimeLogs,
} from '../../utils';
import { TEST_TIMEOUT_CONVENIENCE_BUILD } from '../../constants';

const extraVars = {
  'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
  // we start docker container on localhost
  'zowe_docker_image_url': process.env['ZOWE_DOCKER_URL'],
  'zowe_external_domain_name': 'localhost',
  'zowe_sanity_test_testcases': '--config .mocharc-docker.yml',
}

const testSuiteName = 'Test docker build installation';
describe(testSuiteName, () => {
  beforeAll(() => {
    // validate variables
    checkMandatoryEnvironmentVariables([
      'TEST_SERVER',
      'ZOWE_BUILD_LOCAL',
    ]);
  });

  test('install and verify', async () => {
    await installAndVerifyDockerBuild(
      testSuiteName,
      process.env.TEST_SERVER,
      extraVars
    );
  }, TEST_TIMEOUT_CONVENIENCE_BUILD);

  afterAll(async () => {
    await showZoweRuntimeLogs(process.env.TEST_SERVER, extraVars);
  })
});
