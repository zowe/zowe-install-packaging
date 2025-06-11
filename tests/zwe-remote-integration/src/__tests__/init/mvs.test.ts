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

const testSuiteName = 'init-mvs';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let cleanupDatasets: TestFile[] = []; // a list of datasets deleted after every test

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
    expect.getState().currentTestName = 'before-all-mvs';
    const result = await testRunner.runZweTest(cfgYaml, 'init generate --allow-overwrite');
    expect(result.stdout).not.toBeNull();
    expect(result.rc).toBe(0);
    await testRunner.postTest();
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

  describe('(LONG)', () => {
    /* beforeEach(async () => {
      cfgYaml = ZoweConfig.getZoweYaml();
      // re-created in every `init` subcommand based on changes to zowe yaml command...
      const jcllib: TestFile = { name: REMOTE_SYSTEM_INFO.jcllib, type: FileType.DS_NON_CLUSTER };
      // try to delete everything we know about
      await TestFileActions.deleteAll([jcllib]);
    });

      below test pending review of ZWESISDL, ZWESIS01, zowe_launcher usage in ZWEIMVS2 and
        corresponding update to test framework

    it('creates mvs', async () => {
      const dsRoot = cfgYaml.zowe.setup.dataset;
      // @ts-expect-error schema typing issues in TS
      testRunner.removeDatasetsForTest([dsRoot.authPluginLib]);
      let result = await testRunner.runZweTest(cfgYaml, 'init mvs'); // this runs init generate implicitly
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runZweTest(cfgYaml, 'init mvs');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);


      result = await testRunner.runZweTest(cfgYaml, 'init mvs --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });*/
  });

  describe('(SHORT)', () => {
    it('bad ds prefix post-generate', async () => {
      cfgYaml.zowe.setup.dataset.prefix = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.prefix = '';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('jcllib fails verification', async () => {
      cfgYaml.zowe.setup.dataset.jcllib = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.jcllib = '';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('authLoadLib negatives', async () => {
      cfgYaml.zowe.setup.dataset.authLoadlib = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.authLoadlib = '';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.authLoadlib = 'DOES.NOT.EXIST.ALL';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      cfgYaml.zowe.setup.dataset.authLoadlib = cfgYaml.zowe.setup.dataset.authPluginLib;
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      cfgYaml.zowe.setup.dataset.authLoadlib = cfgYaml.zowe.setup.dataset.prefix + '.SZWEAUTH';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      // with allow-overwrite
      cfgYaml.zowe.setup.dataset.authLoadlib = cfgYaml.zowe.setup.dataset.prefix + '.SZWEAUTH';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      cfgYaml.zowe.setup.dataset.authLoadlib = 'DOES.NOT.EXIST';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      cfgYaml.zowe.setup.dataset.authLoadlib = ZoweConfig.getZoweYaml().zowe.setup.dataset.authLoadlib;
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('parmlib negatives ', async () => {
      cfgYaml.zowe.setup.dataset.parmlib = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.parmlib = '';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.parmlib = 'DOES.NOT.EXIST.ALL';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      cfgYaml.zowe.setup.dataset.parmlib = cfgYaml.zowe.setup.dataset.authPluginLib;
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      // with allow-overwrite
      cfgYaml.zowe.setup.dataset.parmlib = 'DOES.NOT.EXIST';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      cfgYaml.zowe.setup.dataset.parmlib = ZoweConfig.getZoweYaml().zowe.setup.dataset.authLoadlib;
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('authPluginLib negatives ', async () => {
      cfgYaml.zowe.setup.dataset.authPluginLib = null;
      let result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.authPluginLib = '';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      cfgYaml.zowe.setup.dataset.authPluginLib = 'DOES.NOT.EXIST.ALL';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      cfgYaml.zowe.setup.dataset.authPluginLib = cfgYaml.zowe.setup.dataset.parmlib;
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      // with allow-overwrite
      cfgYaml.zowe.setup.dataset.authPluginLib = 'DOES.NOT.EXIST';
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      cfgYaml.zowe.setup.dataset.parmlib = ZoweConfig.getZoweYaml().zowe.setup.dataset.authLoadlib;
      result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('zwesip00 customization ', async () => {
      cfgYaml.zowe.setup.dataset.parmlibMembers = { zis: 'ZWESIP11' };
      const result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('simple --dry-run', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init mvs --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });
  });
});
