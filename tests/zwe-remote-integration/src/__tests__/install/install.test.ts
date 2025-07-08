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
import { FileType, TestFile, TestFileActions } from '../../zos/TestFileActions';

const testSuiteName = 'zwe-install';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let cleanupDatasets: TestFile[] = []; // a list of datasets deleted after every test
  const installDatasets = ['SZWESAMP', 'SZWEEXEC', 'SZWELOAD', 'SZWEAUTH'];

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
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
    it('install with edge-case prefix names', async () => {
      const testCases = [
        `${cfgYaml.zowe.setup.dataset.prefix}.$.#.@.$-.#-.@-`,
        `${cfgYaml.zowe.setup.dataset.prefix}.PR#4282.$$$$$$$$`,
        `${cfgYaml.zowe.setup.dataset.prefix}.PR#4282.$1`,
        `${cfgYaml.zowe.setup.dataset.prefix}.PR#4282.$1-#-@`,
      ];

      for (const test of testCases) {
        cfgYaml.zowe.setup.dataset.prefix = test;
        let result = await testRunner.runZweTest(cfgYaml, `install`);
        expect(result.stdout).not.toBeNull();
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);

        // cover tsoDelete special dataset names
        result = await testRunner.runZweTest(cfgYaml, 'install --allow-overwrite');
        expect(result.stdout).not.toBeNull();
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);

        const cleanupDs: TestFile[] = installDatasets.map((ds) => {
          return { name: `${cfgYaml.zowe.setup.dataset.prefix}.${ds}`, type: FileType.DS_NON_CLUSTER };
        });
        await TestFileActions.deleteAll(cleanupDs);
      }
    }, 300000);

    it('install, re-install and fail, overwrite and succeed', async () => {
      cfgYaml.zowe.setup.dataset.prefix = `${cfgYaml.zowe.setup.dataset.prefix}.INST.TEST`;
      cleanupDatasets.push(
        ...installDatasets.map((ds) => {
          return { name: `${cfgYaml.zowe.setup.dataset.prefix}.${ds}`, type: FileType.DS_NON_CLUSTER };
        }),
      );
      let result = await testRunner.runZweTest(cfgYaml, `install`); // this passes
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runZweTest(cfgYaml, 'install'); // this warns and rc=0, datasets exist
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runZweTest(cfgYaml, 'install'); // this warns again and rc=0 (second call to check system state not mutated)
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runZweTest(cfgYaml, 'install --allow-overwrite'); // this passes
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });
  });

  describe('(SHORT)', () => {
    it('zwe install --help', async () => {
      const result = await testRunner.runZweTest(cfgYaml, `install --help`);
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(100);
    });

    // ensure --ds-prefix is not supported
    it('zwe install invalid parameter', async () => {
      const result = await testRunner.runZweTest(cfgYaml, `install --dry-run --ds-prefix 'SOME.THING'`);
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(102);
    });

    it('zwe install missing prefix', async () => {
      delete cfgYaml.zowe.setup.dataset.prefix;
      const result = await testRunner.runZweTest(cfgYaml, 'install');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);
    });

    it('zwe install missing config', async () => {
      const result = await testRunner.runZweTest(null, 'install');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(108);
    });

    it('zwe install invalid config', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'install --dry-run --config /not/real/config.yml');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('zwe install --dry-run valid ds names', async () => {
      // dataset prefix exists
      let result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runZweTest(cfgYaml, 'install --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      // dataset prefix doesn't exist
      cfgYaml.zowe.setup.dataset.prefix = `${cfgYaml.zowe.setup.dataset.prefix}.NEW`;
      result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runZweTest(cfgYaml, 'install --dry-run --allow-overwrite');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('zwe install invalid dataset name', async () => {
      const invalidDsn = 'INVALID.DSN.LENGTH123123';
      cfgYaml.zowe.setup.dataset.prefix = invalidDsn;
      let result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      delete cfgYaml.zowe.setup.dataset.prefix;
      result = await testRunner.runZweTest(cfgYaml, `install --dry-run`);
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);
    });

    it('zwe install invalid runtime directory', async () => {
      cfgYaml.zowe.runtimeDirectory = `/`; // TODO: verify this should be safe to use with any backend system
      let result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(105);

      cfgYaml.zowe.runtimeDirectory = '/not/a/real/path';
      result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(105);
    });
  });
});
