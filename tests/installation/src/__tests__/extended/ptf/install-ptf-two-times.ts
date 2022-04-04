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
  cleanupSanityTestReportDir,
  copySanityTestReport,
  runAnsiblePlaybook,
  showZoweRuntimeLogs,
  sleep,
} from '../../../utils';
import { TEST_TIMEOUT_SMPE_PTF, ZOWE_FMID } from '../../../constants';

import Debug from 'debug';
const debug = Debug('zowe-install-test:utils');

const testSuiteName = 'Test SMPE PTF installation';
describe(testSuiteName, () => {
  beforeAll(() => {
    // validate variables
    checkMandatoryEnvironmentVariables([
      'TEST_SERVER',
      'ZOWE_BUILD_LOCAL',
    ]);
  });

  test('install same PTF 2 times and verify', async () => {
    const serverId = process.env.TEST_SERVER;
    const extraVars = {
      'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
      'zowe_custom_for_test': 'true',
      'zowe_lock_keystore': 'false',
    };

    debug(`run install-fmid.yml on ${serverId}`);
    const resultFmid = await runAnsiblePlaybook(
      testSuiteName,
      'install-fmid.yml',
      serverId,
      {
        'zowe_build_remote': ZOWE_FMID
      }
    );

    expect(resultFmid.code).toBe(0);

    debug(`run install-ptf.yml on ${serverId}`);
    const resultPtf = await runAnsiblePlaybook(
      testSuiteName,
      'install-ptf.yml',
      serverId,
      extraVars
    );

    expect(resultPtf.code).toBe(0);

    debug(`run install-ptf.yml on ${serverId} again`);
    const resultPtfAgain = await runAnsiblePlaybook(
      testSuiteName,
      'install-ptf.yml',
      serverId,
      extraVars
    );

    expect(resultPtfAgain.code).toBe(0);

    // sleep extra 2 minutes
    debug(`wait extra 2 min before sanity test`);
    await sleep(120000);

    // clean up sanity test folder
    cleanupSanityTestReportDir();

    debug(`run verify.yml on ${serverId}`);
    let resultVerify;
    try {
      resultVerify = await runAnsiblePlaybook(
        testSuiteName,
        'verify.yml',
        serverId
      );
    } catch (e) {
      resultVerify = e;
    }
    expect(resultVerify).toHaveProperty('reportHash');

    // copy sanity test result to install test report folder
    copySanityTestReport(resultVerify.reportHash);

    expect(resultVerify.code).toBe(0);
  }, TEST_TIMEOUT_SMPE_PTF);

  afterAll(async () => {
    await showZoweRuntimeLogs(process.env.TEST_SERVER);
  })
});
