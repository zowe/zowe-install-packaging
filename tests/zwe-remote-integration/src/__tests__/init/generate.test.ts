/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { REMOTE_SYSTEM_INFO } from '../../config/TestConfig';
import ZoweYamlType from '../../config/ZoweYamlType';
import { RemoteTestRunner } from '../../zos/RemoteTestRunner';
import { ZoweConfig } from '../../config/ZoweConfig';
import { FileType, TestFileActions, TestFile } from '../../zos/TestFileActions';

const testSuiteName = 'init-generate';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let defaultCfgYaml: ZoweYamlType;
  let cleanupDatasets: TestFile[] = []; // a list of datasets deleted after every test

  beforeAll(() => {
    testRunner = new RemoteTestRunner(testSuiteName);
  });
  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
    defaultCfgYaml = ZoweConfig.getDefaultsYaml();
  });

  afterEach(async () => {
    await testRunner.postTest();

    // re-created in every `init generate` based on changes to zowe yaml command...
    const jcllib: TestFile = { name: REMOTE_SYSTEM_INFO.jcllib, type: FileType.DS_NON_CLUSTER };

    // try to delete everything we know about
    await TestFileActions.deleteAll([...cleanupDatasets, jcllib]);
    cleanupDatasets = [];
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('disable cfgmgr', async () => {
      cfgYaml.zowe.useConfigmgr = false;
      const result = await testRunner.runZweTest(cfgYaml, 'init generate');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(60); // 60 is expected...
    });

    it('bad ds prefix', async () => {
      cfgYaml.zowe.setup.dataset.prefix = 'ZOWEAD3.ZWETEST.NOEXIST';
      const result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(143);
    });

    it('simple --dry-run', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0); // 60 is expected...
    });

    it('BAD: missing defaults.yaml', async () => {
      await testRunner.removeFileForTest('files/defaults.yaml');
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot(); // FIXME: the snapshot indicates processing continues when it shouldn't
      expect(result.rc).not.toBe(0);
    });

    it('BAD: invalid value defaults.yaml', async () => {
      // @ts-expect-error intentionally setting an incorrect value
      defaultCfgYaml.zowe.configmgr.validation = 'WRONG_VALUE';
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot(); // FIXME: the snapshot indicates processing continues when it shouldn't
      expect(result.rc).not.toBe(0);
    });

    it('BAD: invalid format defaults.yaml', async () => {
      // @ts-expect-error invalid yaml format
      defaultCfgYaml.zowe = '....\n somefield:\n  #another:\n' + defaultCfgYaml.zowe;
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot(); // FIXME: the snapshot indicates processing continues when it shouldn't
      expect(result.rc).not.toBe(0);
    });
  });

  describe('(LONG)', () => {
    it('missing proclib with valid stcs abc', async () => {
      cfgYaml.zowe.setup.dataset.proclib = `${REMOTE_SYSTEM_INFO.prefix}.NOEXIST.PROC`;
      const result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });
  });
});
