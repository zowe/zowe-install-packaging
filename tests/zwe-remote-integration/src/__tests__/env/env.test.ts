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
import * as fs from 'fs-extra';
import { FileType, TestFile, TestFileActions } from '../../zos/TestFileActions';

const testSuiteName = 'generated-env-tests';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let defaultCfgYaml: ZoweYamlType;
  let cleanupFiles: TestFile[] = [];

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
    const cleanSecurityManager = (input: string) => {
      return input.replaceAll(/TSS|ACF2|RACF/gi, 'ESMT'); // ESM TEST
    };
    testRunner.addCleanFn(cleanSecurityManager);
  });
  beforeEach(async () => {
    cfgYaml = ZoweConfig.getZoweYaml();
    defaultCfgYaml = ZoweConfig.getDefaultsYaml();
    const workspaceEnv: TestFile = {
      name: `${cfgYaml.zowe.workspaceDirectory}/.env`,
      type: FileType.USS_DIR,
    };
    await TestFileActions.deleteAll([workspaceEnv]);
    await testRunner.removeUssFileOrDirForTest('components');
    cleanupFiles.push(workspaceEnv);
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFileActions.deleteAll(cleanupFiles);
    cleanupFiles = [];
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('env defaults', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      const envFiles = await testRunner.downloadMaskedUssFilesMatching('*.env', `${cfgYaml.zowe.workspaceDirectory}/.env/`);
      expect(envFiles).not.toBeNull();
      expect(envFiles).toHaveLength(1);
      for (const envFile of envFiles) {
        testRunner.collectTestFile(envFile);
        expect(fs.readFileSync(envFile, 'utf8')).toMatchSnapshot();
      }
    });

    it('env zowe yaml override default', async () => {
      // eslint-disable-next-line
      cfgYaml.zowe.setup.dataset.authPluginLib = 'DOES.EXIST'
      defaultCfgYaml.zowe.setup.dataset.authLoadlib = 'DOES.NOT.EXIST';
      defaultCfgYaml.zowe.setup.dataset.authPluginLib = 'DOES.NOT.EXISTP';

      const result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      const envFiles = await testRunner.downloadMaskedUssFilesMatching('*.env', `${cfgYaml.zowe.workspaceDirectory}/.env/`);
      expect(envFiles).not.toBeNull();
      expect(envFiles).toHaveLength(1);
      for (const envFile of envFiles) {
        testRunner.collectTestFile(envFile);
        expect(fs.readFileSync(envFile, 'utf8')).toMatchSnapshot();
      }
    });

    it('env default override', async () => {
      // eslint-disable-next-line
      if (cfgYaml.zowe.setup.dataset?.authPluginLib) {
        delete cfgYaml.zowe.setup.dataset.authPluginLib;
      }
      defaultCfgYaml.zowe.setup.dataset.authPluginLib = 'DFLT.OVERRIDE.DOES.NOT.EXIST';
      const result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      const envFiles = await testRunner.downloadMaskedUssFilesMatching('*.env', `${cfgYaml.zowe.workspaceDirectory}/.env/`);
      expect(envFiles).not.toBeNull();
      expect(envFiles).toHaveLength(1);
      for (const envFile of envFiles) {
        testRunner.collectTestFile(envFile);
        expect(fs.readFileSync(envFile, 'utf8')).toMatchSnapshot();
      }
    });
  });
});
