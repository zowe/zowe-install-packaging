/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const debug = require('debug')('zowe-install-test:basic:install-pax');

const {
  sleep,
  checkMandatoryEnvironmentVariables,
  runAnsiblePlaybook,
  copySanityTestReport,
} = require('../../utils');
const {
  TEST_TIMEOUT_INSTALL_TEST,
  TEST_TIMEOUT_SANITY_TEST,
} = require('../../constants');

const TEST_SUITE_NAME = 'Test convenient build installation';
let installSucceeded = false;
describe(TEST_SUITE_NAME, () => {
  beforeAll(() => {
    // validate variables
    checkMandatoryEnvironmentVariables([
      'ANSIBLE_HOST',
      'SSH_HOST',
      'SSH_PORT',
      'SSH_USER',
      'SSH_PASSWD',
    ]);
  });

  test('install', async () => {
    debug(`run install.yml on ${process.env.ANSIBLE_HOST}`);
    const result = await runAnsiblePlaybook(
      TEST_SUITE_NAME,
      // 'test.yml',
      'install.yml',
      process.env.ANSIBLE_HOST
    );

    expect(result.code).toBe(0);
    installSucceeded = true;
  }, TEST_TIMEOUT_INSTALL_TEST);

  test('verify', async () => {
    if (!installSucceeded) {
      throw new Error('Install failed, skip verify test');
    }

    // sleep extra 2 minutes
    debug(`wait extra 2 min before sanity test`);
    await sleep(120000);

    debug(`run verify.yml on ${process.env.ANSIBLE_HOST}`);
    const result = await runAnsiblePlaybook(
      TEST_SUITE_NAME,
      'verify.yml',
      process.env.ANSIBLE_HOST
    );
    expect(result).toHaveProperty('reportHash');
    await copySanityTestReport(result.reportHash);

    expect(result.code).toBe(0);
  }, TEST_TIMEOUT_SANITY_TEST);
});
