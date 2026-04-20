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
import { REMOTE_SYSTEM_INFO } from '../../config/TestConfig';
import _ from 'lodash';
import * as path from 'path';

const testSuiteName = 'generated-env-tests';
const resourceDir = path.resolve('src', '__tests__', 'env', '__resources__');
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
    _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
    _.set(cfgYaml, 'zowe.launchScript.startupChecks.ports', 'disabled');
    _.set(cfgYaml, 'zowe.launchScript.startupChecks.user', 'disabled'); // some test runners may be uid(0)
    _.set(cfgYaml, 'zowe.launchScript.startupChecks.certificate', 'disabled'); // always fails in CI

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
    async function snapEnvFiles(cfgYaml: ZoweYamlType) {
      const envFiles = await testRunner.downloadMaskedUssFilesMatching('*.env', `${cfgYaml.zowe.workspaceDirectory}/.env/`);
      expect(envFiles).not.toBeNull();
      expect(envFiles).toHaveLength(1);
      for (const envFile of envFiles) {
        // sort before collection - avoid env ordering errors between systems
        const sortedEnv = fs.readFileSync(envFile, 'utf-8').split('\n').sort();
        fs.writeFileSync(envFile, sortedEnv.join('\n'));
        testRunner.collectTestFile(envFile);
        expect(fs.readFileSync(envFile, 'utf8')).toMatchSnapshot();
      }
    }

    it('env with HA instances', async () => {
      const zoweYaml = ZoweConfig.loadAndOverlay(cfgYaml, resourceDir, 'ha_instances.yaml');
      zoweYaml.zowe.environments = { ZWE_PRIVATE_LOG_LEVEL_ZWELS: 'TRACE' };
      const result = await testRunner.runZweTest(zoweYaml, 'internal start prepare');
      snapEnvFiles(zoweYaml);
      expect(result.rc).toBe(0);
      // Get ZWE_PRIVATE_HA_LIST and ZWE_PRIVATE_HA_LIST_SANITIZED from cleanedStdout. Do not capture all of cleanedStdout,
      //   since the trace logs dump connection-specific settings that are hard to mask
      const haList = /"ZWE_PRIVATE_HA_LIST":".*?"/gim.exec(result.cleanedStdout)[0];
      const sanitizedHaList = /"ZWE_PRIVATE_HA_LIST_SANITIZED":".*?"/gim.exec(result.cleanedStdout)[0];
      expect(haList).toMatchSnapshot();
      expect(sanitizedHaList).toMatchSnapshot();
    });

    it('env with null values', async () => {
      const testFiles = ['setup_cert_keyring.yaml'];
      for (const file of testFiles) {
        const zoweYaml = ZoweConfig.loadZoweYaml(resourceDir, file, true);
        const result = await testRunner.runZweTest(zoweYaml, `internal start prepare`);
        snapEnvFiles(zoweYaml);
        expect(result.rc).toBe(0);
      }
    });

    it('env no node', async () => {
      delete cfgYaml.node;
      let result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.rc).toBe(1);
      cfgYaml.components['app-server'].enabled = false;
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      snapEnvFiles(cfgYaml);
    });

    it('env defaults', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      snapEnvFiles(cfgYaml);
    });

    it('env zowe yaml override default', async () => {
      // eslint-disable-next-line
      cfgYaml.zowe.setup.dataset.authPluginLib = 'DOES.EXIST'
      defaultCfgYaml.zowe.setup.dataset.authLoadlib = 'DOES.NOT.EXIST';
      defaultCfgYaml.zowe.setup.dataset.authPluginLib = 'DOES.NOT.EXISTP';

      const result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      snapEnvFiles(cfgYaml);
    });

    it('env default override', async () => {
      // eslint-disable-next-line
      if (cfgYaml.zowe.setup.dataset?.authPluginLib) {
        delete cfgYaml.zowe.setup.dataset.authPluginLib;
      }
      defaultCfgYaml.zowe.setup.dataset.authPluginLib = 'DFLT.OVERRIDE.DOES.NOT.EXIST';
      const result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      snapEnvFiles(cfgYaml);
    });
  });
});
