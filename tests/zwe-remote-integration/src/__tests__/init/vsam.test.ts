/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { REMOTE_SYSTEM_INFO, TEST_COLLECT_SPOOL } from '../../config/TestConfig';
import ZoweYamlType from '../../config/ZoweYamlType';
import { RemoteTestRunner } from '../../zos/RemoteTestRunner';
import { ZoweYaml } from '../../config/ZoweYaml';
import { FileType, TestFileActions, TestFile } from '../../zos/TestFileActions';

const testSuiteName = 'init-vsam';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let cleanupDatasets: TestFile[] = []; // a list of datasets deleted after every test

  beforeAll(() => {
    testRunner = new RemoteTestRunner(testSuiteName);
  });
  beforeEach(() => {
    cfgYaml = ZoweYaml.basicZoweYaml();
    // customizations for all vsam tests
    cfgYaml.zowe.setup.vsam.name = REMOTE_SYSTEM_INFO.prefix + '.VSAMTEST';
    cfgYaml.zowe.setup.vsam.volume = REMOTE_SYSTEM_INFO.volume;
  });

  afterEach(async () => {
    if (TEST_COLLECT_SPOOL) {
      await testRunner.collectSpool();
    }
    // re-created in every `init vsam` based on changes to zowe yaml command...
    const jcllib: TestFile = { name: REMOTE_SYSTEM_INFO.jcllib, type: FileType.DS_NON_CLUSTER };

    // try to delete everything we know about
    await TestFileActions.deleteAll([...cleanupDatasets, jcllib]);
    cleanupDatasets = [];
  });

  describe('(SHORT)', () => {
    /* it('disable cfgmgr', async () => {
      cfgYaml.zowe.useConfigmgr = false;
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam');
      cleanupDatasets.push({ name: cfgYaml.zowe.setup.vsam.name as string, type: FileType.DS_VSAM });
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(60); // 60 is expected...
    });*/

    it('BAD: bad ds prefix', async () => {
      cfgYaml.zowe.setup.dataset.prefix = 'ZOWEAD6.ZWETEST.NOEXIST';
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(231);
    });

    it('GOOD: simple --dry-run', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0); // 60 is expected...
    });
  });

  describe('(LONG)', () => {
    it('creates vsam', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam');
      cleanupDatasets.push({ name: cfgYaml.zowe.setup.vsam.name as string, type: FileType.DS_VSAM });
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0); // 60 is expected...  });
    });
  });
});
