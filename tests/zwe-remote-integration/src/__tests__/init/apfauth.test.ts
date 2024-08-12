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
import * as zosfiles from '../../zos/Files';
import { RemoteTestRunner } from '../../zos/RemoteTestRunner';
import { ZoweConfig } from '../../config/ZoweConfig';
import { FileType, TestFileActions, TestFile } from '../../zos/TestFileActions';

const testSuiteName = 'init-apfauth';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let cleanupDatasets: TestFile[] = []; // a list of datasets deleted after every test

  beforeAll(() => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml(); // init
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
    beforeEach(async () => {
      // re-created in every `init` subcommand based on changes to zowe yaml command...
      const jcllib: TestFile = { name: REMOTE_SYSTEM_INFO.jcllib, type: FileType.DS_NON_CLUSTER };
      // try to delete everything we know about
      await TestFileActions.deleteAll([jcllib]);
    });

    it('apf empty jcllib', async () => {
      cfgYaml.zowe.setup.dataset.jcllib = null;
      const result = await testRunner.runZweTest(cfgYaml, 'init apfauth --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('apf empty ds prefix', async () => {
      cfgYaml.zowe.setup.dataset.prefix = null;
      const result = await testRunner.runZweTest(cfgYaml, 'init apfauth --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('apf bad ds prefix', async () => {
      cfgYaml.zowe.setup.dataset.prefix = 'BAD.DS.PREFIX.NOEXIST';
      const result = await testRunner.runZweTest(cfgYaml, 'init apfauth --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(143);
    });
  });

  describe('(SHORT)', () => {
    beforeAll(async () => {
      cfgYaml = ZoweConfig.getZoweYaml();
      const result = await testRunner.runZweTest(cfgYaml, 'init generate --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot('short-before-all-apf');
      expect(result.rc).toBe(0);
    });
    it('apf empty jcllib post-generate', async () => {
      cfgYaml.zowe.setup.dataset.jcllib = '';
      const result = await testRunner.runZweTest(cfgYaml, 'init apfauth --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    if (REMOTE_SYSTEM_INFO?.storclas?.length > 0) {
      it('apf sms-managed authLoadLib', async () => {
        const smsDs = `${REMOTE_SYSTEM_INFO.prefix}.APF.LOADLIB`;
        await zosfiles.createPds(smsDs, {
          storclass: REMOTE_SYSTEM_INFO.storclas,
        });
        cleanupDatasets.push({ name: smsDs, type: FileType.DS_NON_CLUSTER });
        cfgYaml.zowe.setup.dataset.authLoadlib = smsDs;
        const result = await testRunner.runZweTest(cfgYaml, 'init apfauth --dry-run');
        expect(result.stdout).not.toBeNull();
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);
      });
      it('apf sms-managed authPluginLib', async () => {
        const smsDs = `${REMOTE_SYSTEM_INFO.prefix}.APF.PLUGLIB`;
        await zosfiles.createPds(smsDs, {
          storclass: REMOTE_SYSTEM_INFO.storclas,
        });
        cleanupDatasets.push({ name: smsDs, type: FileType.DS_NON_CLUSTER });
        cfgYaml.zowe.setup.dataset.authPluginLib = smsDs;
        const result = await testRunner.runZweTest(cfgYaml, 'init apfauth --dry-run');
        expect(result.stdout).not.toBeNull();
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);
      });
      it('apf sms-managed authLoadLib and authPluginLib', async () => {
        const loadSmsDs = `${REMOTE_SYSTEM_INFO.prefix}.APF.LOADLIB`;
        const plugSmsDs = `${REMOTE_SYSTEM_INFO.prefix}.APF.PLUGLIB`;
        await zosfiles.createPds(loadSmsDs, {
          storclass: REMOTE_SYSTEM_INFO.storclas,
        });
        await zosfiles.createPds(plugSmsDs, {
          storclass: REMOTE_SYSTEM_INFO.storclas,
        });
        cleanupDatasets.push({ name: loadSmsDs, type: FileType.DS_NON_CLUSTER });
        cleanupDatasets.push({ name: plugSmsDs, type: FileType.DS_NON_CLUSTER });
        cfgYaml.zowe.setup.dataset.authLoadlib = loadSmsDs;
        cfgYaml.zowe.setup.dataset.authPluginLib = plugSmsDs;
        const result = await testRunner.runZweTest(cfgYaml, 'init apfauth --dry-run');
        expect(result.stdout).not.toBeNull();
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);
      });
    } else {
      it.skip('apf sms-managed authLoadLib', () => {});
      it.skip('apf sms-managed authPluginLib', () => {});
      it.skip('apf sms-managed authLoadLib and authPluginLib', () => {});
    }

    it('apf bad authLoadLib', async () => {
      cfgYaml.zowe.setup.dataset.authLoadlib = 'DOES.NOT.EXIST';
      const result = await testRunner.runZweTest(cfgYaml, 'init apfauth --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(64);
    });

    it('apf bad authPluginLib', async () => {
      cfgYaml.zowe.setup.dataset.authPluginLib = 'DOES.NOT.EXIST';
      const result = await testRunner.runZweTest(cfgYaml, 'init apfauth --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(64);
    });

    it('apf simple --dry-run', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init apfauth --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0); // 60 is expected...
    });
  });
});
