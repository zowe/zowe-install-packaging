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
import * as path from 'path';
import { TestFile, TestFileActions } from '../../zos/TestFileActions';

const testSuiteName = 'migrate-for-kubernetes';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  const cleanupFiles: TestFile[] = []; // a list of datasets deleted after every test
  // let defaultCfgYaml: ZoweYamlType;
  const yamlResourceDir = path.resolve('src', '__tests__', 'migrate', '__resources__');

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    testRunner.addCleanFn((output) => {
      return output
        .replace(/keystore\.p12:.*$/gm, 'keystore.p12: [MASKED]')
        .replace(/truststore\.p12:.*$/gm, 'truststore.p12: [MASKED]')
        .replace(/^(\s+).*BEGIN CERTIFICATE[\s\S]*?END CERTIFICATE.*$/gm, '$1[MASKED]')
        .replace(/^(\s+).*BEGIN PRIVATE KEY[\s\S]*?END PRIVATE KEY.*$/gm, '$1[MASKED]');
    });

    cfgYaml = ZoweConfig.getZoweYaml();
    cfgYaml.zowe.setup.certificate.defaultCfgYaml = ZoweConfig.getDefaultsYaml();
  });
  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
    // defaultCfgYaml = ZoweConfig.getDefaultsYaml();
  });

  afterEach(async () => {
    TestFileActions.deleteAll(cleanupFiles);
    await testRunner.postTest();
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('run migrate for kubernetes', async () => {
      const scenarioYml = 'setup.scenario.1.yml';
      cfgYaml = ZoweConfig.loadAndOverlay(cfgYaml, yamlResourceDir, scenarioYml);
      let result = await testRunner.runZweTest(cfgYaml, 'init certificate');
      result = await testRunner.runZweTest(cfgYaml, 'migrate for kubernetes');
      expect(result.rc).toBe(0);
      expect(result.cleanedStdout).toMatchSnapshot();
    });
  });
});
