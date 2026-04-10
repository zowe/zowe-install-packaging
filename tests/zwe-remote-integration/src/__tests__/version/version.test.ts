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

const testSuiteName = 'zwe-version';
describe(`${testSuiteName}`, () => {
  let cfgYaml: ZoweYamlType;
  let testRunner: RemoteTestRunner;
  let cleanupDatasets: TestFile[] = []; // a list of datasets deleted after every test

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
  });

  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFileActions.deleteAll(cleanupDatasets);
    cleanupDatasets = [];
  });

  afterAll(async () => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('zwe version', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'version');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('zwe version - missing runtimeDir', async () => {
      delete cfgYaml.zowe.runtimeDirectory;
      const result = await testRunner.runZweTest(cfgYaml, 'version');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(106);
    });

    it('zwe version - no manifest', async () => {
      await testRunner.removeUssFileOrDirForTest('manifest.json');
      const result = await testRunner.runZweTest(cfgYaml, 'version');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(150);
    });

    it('zwe version - corrupt manifest json', async () => {
      await testRunner.removeUssFileOrDirForTest('manifest.json');
      await testRunner.runRaw(`echo '{' > manifest.json`);
      const result = await testRunner.runZweTest(cfgYaml, 'version');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(71);
    });

    it('zwe version - manifest missing version field', async () => {
      await testRunner.removeUssFileOrDirForTest('manifest.json');
      await testRunner.runRaw(`echo '{"name":"Zowe"}' > manifest.json`);
      const result = await testRunner.runZweTest(cfgYaml, 'version');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(71);
    });

    it('zwe version - manifest missing build section', async () => {
      await testRunner.removeUssFileOrDirForTest('manifest.json');
      await testRunner.runRaw(`echo '{"version":"99.0.0"}' > manifest.json`);
      const result = await testRunner.runZweTest(cfgYaml, 'version');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(71);
    });
  });
});
