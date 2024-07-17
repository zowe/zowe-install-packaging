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

const testSuiteName = 'init-vsam';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let cleanupDatasets: TestFile[] = []; // a list of datasets deleted after every test

  beforeAll(() => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
  });
  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
    // customizations for all vsam tests
    cfgYaml.zowe.setup.vsam.name = REMOTE_SYSTEM_INFO.prefix + '.VSAMTEST';
    cfgYaml.zowe.setup.vsam.volume = REMOTE_SYSTEM_INFO.volume;
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFileActions.deleteAll(cleanupDatasets);
    cleanupDatasets = [];
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(LONG)', () => {
    beforeEach(async () => {
      // re-created in every `init` subcommand based on changes to zowe yaml command...
      const jcllib: TestFile = { name: REMOTE_SYSTEM_INFO.jcllib, type: FileType.DS_NON_CLUSTER };
      // try to delete everything we know about
      await TestFileActions.deleteAll([jcllib]);
    });

    it('creates vsam', async () => {
      cleanupDatasets.push({ name: cfgYaml.zowe.setup.vsam.name as string, type: FileType.DS_VSAM });
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });
  });

  describe('(SHORT)', () => {
    beforeAll(async () => {
      cfgYaml = ZoweConfig.getZoweYaml();
      const result = await testRunner.runZweTest(cfgYaml, 'init generate --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot('short-before-all-vsam');
      expect(result.rc).toBe(0);
    });

    it('skip non-vsam caching service', async () => {
      // @ts-expect-error dynamic property access not in schema
      cfgYaml.components['caching-service'].storage.mode = 'INFINISPAN';
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('skip undefined caching service', async () => {
      cfgYaml.components = null;
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('unset ds prefix', async () => {
      cfgYaml.zowe.setup.dataset.prefix = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.prefix = '';
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('unset jcllib', async () => {
      cfgYaml.zowe.setup.dataset.jcllib = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.jcllib = '';
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('invalid NONRLS configurations', async () => {
      cfgYaml.zowe.setup.vsam.mode = 'NONRLS';

      // null(empty) vol
      cfgYaml.zowe.setup.vsam.volume = null;
      cfgYaml.zowe.setup.vsam.name = 'SOME.VSAM.NAME';
      let result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      // empty(str) vol
      cfgYaml.zowe.setup.vsam.volume = '';
      cfgYaml.zowe.setup.vsam.name = 'SOME.VSAM.NAME';
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);

      // null(empty) name
      cfgYaml.zowe.setup.vsam.volume = 'SOMEVOL';
      cfgYaml.zowe.setup.vsam.name = null;
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);

      // empty(str) name
      cfgYaml.zowe.setup.vsam.volume = 'SOMEVOL';
      cfgYaml.zowe.setup.vsam.name = '';
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);

      // null(empty) both
      cfgYaml.zowe.setup.vsam.volume = null;
      cfgYaml.zowe.setup.vsam.name = null;
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      // empty(str) both
      cfgYaml.zowe.setup.vsam.volume = '';
      cfgYaml.zowe.setup.vsam.name = '';
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);

      // valid RLS config (invalid for NONRLS)
      cfgYaml.zowe.setup.vsam.volume = '';
      cfgYaml.zowe.setup.vsam.storageClass = 'STG1';
      cfgYaml.zowe.setup.vsam.name = 'SOME.VSAM.NAME';
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);
    });

    it('valid NONRLS configurations', async () => {
      cfgYaml.zowe.setup.vsam.mode = 'NONRLS';
      cfgYaml.zowe.setup.vsam.volume = 'VOL001';
      cfgYaml.zowe.setup.vsam.name = 'SOME.VSAM.NAME';
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('invalid RLS configurations', async () => {
      cfgYaml.zowe.setup.vsam.mode = 'RLS';

      // null(empty) stgClass
      cfgYaml.zowe.setup.vsam.storageClass = null;
      cfgYaml.zowe.setup.vsam.name = 'SOME.VSAM.NAME';
      let result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      // empty(str) stgClass
      cfgYaml.zowe.setup.vsam.storageClass = '';
      cfgYaml.zowe.setup.vsam.name = 'SOME.VSAM.NAME';
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);

      // checking null / empty same same logic as NONRLS

      // null(empty) both
      cfgYaml.zowe.setup.vsam.storageClass = null;
      cfgYaml.zowe.setup.vsam.name = null;
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      // empty(str) both
      cfgYaml.zowe.setup.vsam.storageClass = '';
      cfgYaml.zowe.setup.vsam.name = '';
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);

      // valid NONRLS config (invalid for RLS)
      cfgYaml.zowe.setup.vsam.volume = 'SOMEVOL';
      cfgYaml.zowe.setup.vsam.storageClass = '';
      cfgYaml.zowe.setup.vsam.name = 'SOME.VSAM.NAME';
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);
    });

    it('valid RLS configuration', async () => {
      cfgYaml.zowe.setup.vsam.mode = 'RLS';
      cfgYaml.zowe.setup.vsam.storageClass = 'STG001';
      cfgYaml.zowe.setup.vsam.name = 'SOME.VSAM.NAME';
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('unset vsam mode', async () => {
      cfgYaml.zowe.setup.vsam.mode = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      // @ts-expect-error forced schema error
      cfgYaml.zowe.setup.vsam.mode = '';
      result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('simple --dry-run', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init vsam --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });
  });
});
