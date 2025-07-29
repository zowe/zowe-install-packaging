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
import * as YAML from 'yaml';
import * as _ from 'lodash';

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
        _.set(cfgYaml, 'zowe.setup.dataset.prefix', test);
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
          return { name: `${test}.${ds}`, type: FileType.DS_NON_CLUSTER };
        });
        await TestFileActions.deleteAll(cleanupDs);
      }
    }, 500000);

    it('install, re-install and fail, overwrite and succeed', async () => {
      _.set(cfgYaml, 'zowe.setup.dataset.prefix', `${cfgYaml.zowe.setup.dataset.prefix}.INST.TEST`);
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
    it('cover different configmgr and jcl combinations', async () => {
      // set session libraries
      for (const jclSetting of [true, false]) {
        for (const cmgrSetting of [true, false]) {
          for (const flag of ['--jcl', '--configmgr', '', '-c "FILE(zowe.test.yaml)"']) {
            cfgYaml = ZoweConfig.getZoweYaml();
            _.set(cfgYaml, 'zowe.setup.jcl.enable', jclSetting);
            _.set(cfgYaml, 'zowe.useConfigmgr', cmgrSetting);
            const result = await testRunner.runZweTest(cfgYaml, `install --dry-run ${flag}`);
            expect(result.stdout).not.toBeNull();
            expect(`jcl: ${jclSetting}, cmgr: ${cmgrSetting}, extra flag: ${flag}, rc: ${result.rc}`).toMatchSnapshot(); // also capture test settings to make snapshots
            expect(result.cleanedStdout).toMatchSnapshot();
            // easier to read
            // expect(result.rc).toBe(0);  -- captured the rc in the snapshot
          }
        }
      }
    }, 200000);

    it('install via PARMLIB and exported variable', async () => {
      const testParmlib = `${cfgYaml.zowe.setup.dataset.parmlib}`;
      const testMember = `${testParmlib}(ZWECNF)`;

      const zweYamlString = YAML.stringify(cfgYaml, { nullStr: '' });
      await testRunner.uploadToDatasetForTest(zweYamlString, testMember);
      await testRunner.collectTestContent(zweYamlString, 'parmlib.zowe.yaml');

      const configString = `PARMLIB(${testMember}):FILE(./files/defaults.yaml)`;

      let result = await testRunner.runZweTest(null, `zwe install --dry-run --config '${configString}'`);
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runRaw(`
        export ZWE_CLI_PARAMETER_CONFIG='${configString}' && \
        ./bin/zwe install --dry-run`);

      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('bad runtimeDirectory, missing ZWEINSTL', async () => {
      const emptyDs = `${cfgYaml.zowe.setup.dataset.prefix}.NEW`;
      _.set(cfgYaml, 'zowe.setup.dataset.prefix', emptyDs);
      await testRunner.removeUssFileOrDirForTest('files/SZWESAMP/ZWEINSTL');
      const result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(159);
    });

    it('zwe install --help', async () => {
      const result = await testRunner.runZweTest(cfgYaml, `install --help`);
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(100);
    });

    // ensure --ds-prefix is not supported in jcl mode
    it('zwe install invalid parameter', async () => {
      let result = await testRunner.runZweTest(cfgYaml, `install --dry-run --ds-prefix 'SOME.THING'`);
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(102);

      cfgYaml.zowe.setup.jcl.enable = false;
      result = await testRunner.runZweTest(cfgYaml, `install --dry-run --ds-prefix 'SOME.THING'`);
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
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
      expect(result.rc).toBe(109);
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
      const dsPrefix = `${cfgYaml.zowe.setup.dataset.prefix}.NEW`;
      // cautionary - make sure they're not on the system
      for (const dsSuffix of installDatasets) {
        await TestFileActions.deleteAll([{ name: `${dsPrefix}.${dsSuffix}`, type: FileType.DS_NON_CLUSTER }]);
      }

      _.set(cfgYaml, 'zowe.setup.dataset.prefix', dsPrefix);
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
      _.set(cfgYaml, 'zowe.setup.dataset.prefix', invalidDsn);
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
      _.set(cfgYaml, 'zowe.runtimeDirectory', `/`); // TODO: verify this should be safe to use with any backend system
      let result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(105);

      _.set(cfgYaml, 'zowe.runtimeDirectory', '/not/a/real/path');
      result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(105);
    });

    it('jcl header single line', async () => {
      // eslint-disable-next-line
      _.set(cfgYaml, 'zowe.setup.jcl.header', "'SOMEJOB',(0000000000)");
      const result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('jcl header multi line', async () => {
      // eslint-disable-next-line
      const longString = "LONGFIELD1,LONGFIELD2,LONGFIELD3,ANOTHER,FIELD,GOING,WAY,PAST,EIGHTY,CHARACTERS,INCLUDING,THIS";
      let jclLines = [`'SOMEJOB'`, `//  (0000000000)`, '//  ' + longString, 'SYSAFF=SYS1'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines.join('\n'));
      let result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(144);

      // this is technically not valid JCL, but fits in 80 chars
      jclLines = [`'SOMEJOB'`, `//    (0000000000)`, ('//    ' + longString).slice(0, 79), '//    SYSAFF=SYS1'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines.join('\n'));
      result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      // with idx 0, the slice is invalid for first line.
      jclLines = [longString.slice(0, 79), `//    (0000000000)`, '//    SOMEJOB', '//    SYSAFF=SYS1'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines.join('\n'));
      result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(144);

      // this is the right max width
      jclLines = [longString.slice(0, 80 - ('//ABCABCDE JOB '.length + 1)), `// (0000000000),`, `// 'SOMEJOB',`, '// SYSAFF=SYS1'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines.join('\n'));
      result = await testRunner.runZweTest(cfgYaml, 'install --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });
  });
});
