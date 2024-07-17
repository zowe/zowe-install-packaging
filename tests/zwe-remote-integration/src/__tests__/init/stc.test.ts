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
import * as zosfiles from '../../zos/Files';
import { ZoweConfig } from '../../config/ZoweConfig';
import { FileType, TestFileActions, TestFile } from '../../zos/TestFileActions';

const testSuiteName = 'init-stc';
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

    // implicit 'init generate'
    it('run setup with defaults', async () => {
      const proc: string = cfgYaml.zowe.setup.dataset.proclib as string;
      const stcs = cfgYaml.zowe.setup.security.stcs;
      cleanupDatasets.push({ name: `${proc}(${stcs.zowe})`, type: FileType.DS_NON_CLUSTER });
      cleanupDatasets.push({ name: `${proc}(${stcs.aux})`, type: FileType.DS_NON_CLUSTER });
      cleanupDatasets.push({ name: `${proc}(${stcs.zis})`, type: FileType.DS_NON_CLUSTER });
      const result = await testRunner.runZweTest(cfgYaml, 'init stc');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('run stc setup, then overwrite, then run again', async () => {
      const proc: string = cfgYaml.zowe.setup.dataset.proclib as string;
      const stcs = cfgYaml.zowe.setup.security.stcs;
      cleanupDatasets.push({ name: `${proc}(${stcs.zowe})`, type: FileType.DS_NON_CLUSTER });
      cleanupDatasets.push({ name: `${proc}(${stcs.aux})`, type: FileType.DS_NON_CLUSTER });
      cleanupDatasets.push({ name: `${proc}(${stcs.zis})`, type: FileType.DS_NON_CLUSTER });
      let result = await testRunner.runZweTest(cfgYaml, 'init stc');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runZweTest(cfgYaml, 'init stc --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      // this should fail or warn the user
      result = await testRunner.runZweTest(cfgYaml, 'init stc');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });
  });

  describe('(SHORT)', () => {
    beforeAll(async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init generate --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot('short-before-all-stc');
      expect(result.rc).toBe(0);
    });

    it('wrong ds prefix', async () => {
      cfgYaml.zowe.setup.dataset.prefix = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.prefix = '';
      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('wrong proclib', async () => {
      cfgYaml.zowe.setup.dataset.proclib = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.proclib = '';
      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.proclib = 'INVALID.PROCLIB.DEFINITION1';
      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('wrong jcllib', async () => {
      cfgYaml.zowe.setup.dataset.jcllib = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.jcllib = '';
      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('invalid stc configurations', async () => {
      cfgYaml.zowe.setup.security.stcs.aux = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.security.stcs.aux = '';
      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.security.stcs.aux = 'TOOLONGTOO';
      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.security.stcs.zis = null;
      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.security.stcs.zis = '';
      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.security.stcs.zowe = null;
      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.security.stcs.zowe = '';
      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('zos stc exists', async () => {
      const proc: string = cfgYaml.zowe.setup.dataset.proclib as string;
      const stcs = cfgYaml.zowe.setup.security.stcs;
      await zosfiles.uploadMember(proc, stcs.zowe as string, 'DUMMY');
      cleanupDatasets.push({ name: `${proc}(${stcs.zowe})`, type: FileType.DS_NON_CLUSTER });
      let result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('zis stc exists', async () => {
      const proc: string = cfgYaml.zowe.setup.dataset.proclib as string;
      const stcs = cfgYaml.zowe.setup.security.stcs;
      await zosfiles.uploadMember(proc, stcs.zis as string, 'DUMMY');
      cleanupDatasets.push({ name: `${proc}(${stcs.zis})`, type: FileType.DS_NON_CLUSTER });
      let result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('aux stc exists', async () => {
      const proc: string = cfgYaml.zowe.setup.dataset.proclib as string;
      const stcs = cfgYaml.zowe.setup.security.stcs;
      await zosfiles.uploadMember(proc, stcs.aux as string, 'DUMMY');
      cleanupDatasets.push({ name: `${proc}(${stcs.aux})`, type: FileType.DS_NON_CLUSTER });
      let result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('valid config empty proclib', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init stc --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });
  });
});
