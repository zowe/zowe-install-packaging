/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { ZoweConfig } from '../../config/ZoweConfig';
import ZoweYamlType from '../../config/ZoweYamlType';
import { RemoteTestRunner } from '../../zos/RemoteTestRunner';
import * as path from 'path';

const testSuiteName = 'unit-test-suite';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType = ZoweConfig.getZoweYaml();
  const configMgrResourceDir = path.resolve('src', '__tests__', 'unit', '__configmgr__');

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
    await testRunner.buildAndUploadUnitTests(configMgrResourceDir);
  });

  beforeEach(async () => {
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('run all unit tests', async () => {
      cfgYaml.zowe.launchScript.startupChecks.certificate = 'disabled';
      cfgYaml.zowe.launchScript.startupChecks.user = 'disabled';
      const results = await testRunner.runUnitTests(cfgYaml, configMgrResourceDir);
      for (const result of results) {
        // result.cleanedStdout
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0); // debugging currently hard, manually find output
      }
    });
  });
});
