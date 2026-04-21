/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import _ from 'lodash';
import { ZoweConfig } from '../../config/ZoweConfig';
import ZoweYamlType from '../../config/ZoweYamlType';
import { RemoteTestRunner } from '../../zos/RemoteTestRunner';
import { TestFile, TestFileActions } from '../../zos/TestFileActions';

const testSuiteName = 'zwe-validate-components';

/** Remote integration env only ships zss under the runtime tree; other component dirs are absent. */
function disableAllComponentsExceptZss(cfg: ZoweYamlType) {
  if (!cfg.components) {
    return;
  }
  for (const id of Object.keys(cfg.components)) {
    const entry = cfg.components[id] as { enabled?: boolean };
    if (entry && typeof entry === 'object') {
      entry.enabled = id === 'zss';
    }
  }
}

describe(`${testSuiteName}`, () => {
  let cfgYaml: ZoweYamlType;
  let testRunner: RemoteTestRunner;
  let cleanupDatasets: TestFile[] = [];

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
  });
  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
    // Fresh yaml each test (cases delete fields or flip flags); keep only zss enabled to match remote layout.
    disableAllComponentsExceptZss(cfgYaml);
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFileActions.deleteAll(cleanupDatasets);
    cleanupDatasets = [];
  });

  afterAll(async () => {
    await testRunner.uploadDefaultsYaml(ZoweConfig.getDefaultsYaml(), undefined, true);
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('validate components for enabled components only', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'validate components');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('validate components with -o component subset (zss only on remote runtime)', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'validate components -o zss');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('validate components -o rejects ids not defined in zowe.yaml', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'validate components -o not-a-real-component');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(75);
    });

    it('validate components requires zowe.runtimeDirectory', async () => {
      delete cfgYaml.zowe.runtimeDirectory;
      const result = await testRunner.runZweTest(cfgYaml, 'validate components');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(76);
    });

    it('validate components returns 329 when no components are defined in zowe.yaml', async () => {
      const customDefaults = ZoweConfig.getDefaultsYaml();
      customDefaults.components = {} as ZoweYamlType['components'];
      cfgYaml.components = {} as ZoweYamlType['components'];
      const result = await testRunner.runZweTestWithDefaults(cfgYaml, customDefaults, 'validate components');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(73);
    });

    // Enables only gateway; remote test runtime has no components/gateway (unlike zss).
    it('validate components returns 328 when a checked component directory is missing (ZWEL0330E)', async () => {
      cfgYaml.components.zss.enabled = false;
      cfgYaml.components.gateway.enabled = true;
      const result = await testRunner.runZweTest(cfgYaml, 'validate components');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(72);
    });

    it('validate components -o checks named components even when disabled in yaml', async () => {
      cfgYaml.components.zss.enabled = false;
      const result = await testRunner.runZweTest(cfgYaml, 'validate components -o zss');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });
  });
});
