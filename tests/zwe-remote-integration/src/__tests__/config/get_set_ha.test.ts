/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import ZoweYamlType from '../../config/ZoweYamlType';
import { RemoteTestRunner } from '../../zos/RemoteTestRunner';
import { ZoweConfig } from '../../config/ZoweConfig';
import { TestFile, TestFileActions } from '../../zos/TestFileActions';
import * as fs from 'fs-extra';
import * as path from 'path';

const testSuiteName = 'internal-config-get-and-set';
const yamlResourceDir = path.resolve('src', '__tests__', 'config', '__resources__');
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType = ZoweConfig.getZoweYaml();
  let cleanupFiles: TestFile[] = [];

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  beforeEach(async () => {
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  afterEach(async () => {
    await TestFileActions.deleteAll(cleanupFiles);
    await testRunner.postTest();
    cleanupFiles = [];
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('config get operations', async () => {
      const fullCfg = ZoweConfig.loadAndOverlay(cfgYaml, yamlResourceDir, 'zowe.1ha.yaml');
      const testCases = [
        'config get --ha-instance lpar1 --path hostname',
        'config get --ha-instance LPAR1 --path hostname',
        'config get --ha-instance lpar-2 --path hostname',
        'config get --ha-instance LPAR#2 --path hostname',
        'config get --ha-instance lpAr_2 --path hostname',
        'config get --ha-instance LPaR_3 --path hostname',
        'config get --ha-instance LPaR_3 --path zowe.setup.dataset --format',
      ];
      for (const test of testCases) {
        const result = await testRunner.runZweTest(fullCfg, test);
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);
      }
    });

    // no node + app-server enabled = fail, no node + app-server disabled = pass
    it('config set operations', async () => {
      const fullCfg = ZoweConfig.loadAndOverlay(cfgYaml, yamlResourceDir, 'zowe.1ha.yaml');
      const testCases = [
        'internal config set --ha-instance LPAR2 --path hostname --value new-lpar2.example.com',
        'internal config set --path zowe.setup.jcl.header --value 123456 --string',
        'internal config set --ha-instance lpar1 --path hostname --value new-lpar.example.com',
      ];
      for (const test of testCases) {
        const result = await testRunner.runZweTest(fullCfg, test);
        expect(result.cleanedStdout).toMatchSnapshot();
        const updatedYaml = (await testRunner.downloadMaskedUssFilesMatching('zowe.test.yaml'))[0];
        expect(fs.readFileSync(updatedYaml, 'utf-8')).toMatchSnapshot();
      }
    });
  });

  describe('(LONG)', () => {});
});
