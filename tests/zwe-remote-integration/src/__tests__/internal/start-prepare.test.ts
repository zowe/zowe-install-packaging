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
import * as yaml from 'yaml';
import { FileType, TestFile, TestFileActions } from '../../zos/TestFileActions';

const testSuiteName = 'start-prepare-tests';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let defaultCfgYaml: ZoweYamlType;
  let workspaceEnv: TestFile;

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
    defaultCfgYaml = ZoweConfig.getDefaultsYaml();
    workspaceEnv = {
      name: `${cfgYaml.zowe.workspaceDirectory}/.env`,
      type: FileType.USS_DIR,
    };
    const cleanSecurityManager = (input: string) => {
      return input.replaceAll(/TSS|ACF2|RACF/gi, 'ESMT'); // ESM TEST
    };
    testRunner.addCleanFn(cleanSecurityManager);
  });
  beforeEach(async () => {
    cfgYaml = ZoweConfig.getZoweYaml();
    defaultCfgYaml = ZoweConfig.getDefaultsYaml();
    await testRunner.removeUssFileOrDirForTest('components/zss/bin/validate.sh'); // validate script causes rc=1
    await TestFileActions.deleteAll([workspaceEnv]);
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFileActions.deleteAll([workspaceEnv]);
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('default startupChecks behavior', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      expect(result.cleanedStdout).toMatchSnapshot();
    });

    it('set startupChecks disabled', async () => {
      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'disabled';
      const result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      expect(result.cleanedStdout).toMatchSnapshot();
    });

    it('set startupChecks warn', async () => {
      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'warn';
      const result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      expect(result.cleanedStdout).toMatchSnapshot();
    });

    it('test combinations of startup default and ports', async () => {
      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'warn';
      defaultCfgYaml.zowe.launchScript.startupChecks.ports = 'disabled';
      let result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      expect(result.cleanedStdout).toMatchSnapshot();

      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'exit';
      defaultCfgYaml.zowe.launchScript.startupChecks.ports = 'disabled';
      result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      expect(result.cleanedStdout).toMatchSnapshot();

      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'disabled';
      defaultCfgYaml.zowe.launchScript.startupChecks.ports = 'warn';
      result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      expect(result.cleanedStdout).toMatchSnapshot();

      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'disabled';
      defaultCfgYaml.zowe.launchScript.startupChecks.ports = 'exit';
      result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.rc).toBe(0);
      expect(result.cleanedStdout).toMatchSnapshot();
    });
  });
});
