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
  showZoweRuntimeLogs,
  installAndVerifyExtension,
  installAndVerifyConvenienceBuild,
  installAndVerifySmpePtf,
} from '../../utils';
import {TEST_TIMEOUT_SMPE_PTF} from '../../constants';

let beforeAllResult = false;
const testSuiteName = 'Test sample extensions installation and verify';
describe(testSuiteName, () => {
  beforeAll(async () => {
    // validate variables
    checkMandatoryEnvironmentVariables([
      'TEST_SERVER',
      'ZOWE_BUILD_LOCAL',
      'EXTENSIONS_LIST',
    ]);
    //await installConvBuild
    //remove verification of conv build - for optimal runtime purposes
    if(process.env['ZOWE_BUILD_LOCAL'].includes(".pax")){
      await installAndVerifyConvenienceBuild(
        testSuiteName,
        process.env.TEST_SERVER,
        {
          'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
          'zowe_lock_keystore': 'false',
          //skip_start - for optimal runtime purposes
        }
      );
    } else if(process.env['ZOWE_BUILD_LOCAL'].includes(".zip")){
      await installAndVerifySmpePtf(
        testSuiteName,
        process.env.TEST_SERVER,
        {
          'zowe_build_local': process.env['ZOWE_BUILD_LOCAL'],
          'zowe_lock_keystore': 'false',
        },
        true
      );
    }
    beforeAllResult = true;
  }, TEST_TIMEOUT_SMPE_PTF);

  process.env.EXTENSIONS_LIST.split(',').forEach((extension) => {
    if (!extension){
      return;
    }
    const extensionArray = extension.split(':');
    if (extensionArray.length !== 2){
      return;
    }

    test(`install and verify ${extensionArray[0]}`, async () => {
      expect(beforeAllResult).toBe(true);
      await installAndVerifyExtension(
        testSuiteName,
        process.env.TEST_SERVER,
        {
          'zowe_ext_url': ((extensionArray[1].startsWith('https://') || extensionArray[1].startsWith('http://')) ? extensionArray[1] : `https://zowe.jfrog.io/artifactory/${extensionArray[1]}`),
          'component_id': extensionArray[0],
        }
      );
    }, TEST_TIMEOUT_SMPE_PTF);
  });

  afterAll(async () => {
    await showZoweRuntimeLogs(process.env.TEST_SERVER);
  })
});
