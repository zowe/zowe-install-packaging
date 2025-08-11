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
import { TestFile, TestFileActions } from '../../zos/TestFileActions';

const testSuiteName = 'zwe-validate-commands';
describe(`${testSuiteName}`, () => {
  let cfgYaml: ZoweYamlType;
  let testRunner: RemoteTestRunner;
  let cleanupDatasets: TestFile[] = []; // a list of datasets deleted after every test

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
  });
  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFileActions.deleteAll(cleanupDatasets);
    cleanupDatasets = [];
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('validate port bind', async () => {});

    it('config validate alias', async () => {
      testRunner.addCleanFn((output) => {
        // removes timestamps of the form YYYY-MM-DD <SOMEID:[somedigits]>
        return output.replaceAll(/\d\d\d\d.*?\d\d\d> /gim, '');
      });
      const resultCfgVal = await testRunner.runZweTest(cfgYaml, 'config validate');
      expect(resultCfgVal.stdout).not.toBeNull();
      expect(resultCfgVal.cleanedStdout).toMatchSnapshot();
      expect(resultCfgVal.rc).toBe(0);

      const resultValCfg = await testRunner.runZweTest(cfgYaml, 'validate config');
      expect(resultValCfg.stdout).not.toBeNull();
      expect(resultValCfg.cleanedStdout).toMatchSnapshot();
      expect(resultValCfg.rc).toBe(0);

      expect(resultCfgVal.cleanedStdout).toEqual(resultValCfg.cleanedStdout);
    });
  });
});
