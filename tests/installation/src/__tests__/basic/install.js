/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const debug = require('debug')('test:basic:install-convenient-build');

const { checkMadatoryEnvironmentVariabls, runAnsiblePlaybook, copySanityTestReport } = require('../../utils');

const TEST_SUITE_NAME = 'Test convenient build installation';
describe(TEST_SUITE_NAME, () => {
  beforeAll(() => {
    // validate variables
    checkMadatoryEnvironmentVariabls([
      'ANSIBLE_HOST',
      'SSH_HOST',
      'SSH_PORT',
      'SSH_USER',
      'SSH_PASSWD',
    ]);
  });

  test('install', async () => {
    debug(`run install.yml on ${process.env.ANSIBLE_HOST}`);
    const result = await runAnsiblePlaybook(TEST_SUITE_NAME, 'install.yml', process.env.ANSIBLE_HOST);

    expect(result.code).toBe(0);
  });

  test('verify', async () => {
    debug(`run verify.yml on ${process.env.ANSIBLE_HOST}`);
    const result = await runAnsiblePlaybook(TEST_SUITE_NAME, 'verify.yml', process.env.ANSIBLE_HOST);
    expect(result).toHaveProperty('reportId');
    await copySanityTestReport(result.reportId);

    expect(result.code).toBe(0);
  });
});
