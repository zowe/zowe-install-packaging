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
import * as fs from 'fs-extra';
import * as _ from 'lodash';
import path from 'path';

const testSuiteName = 'init-generate';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let defaultCfgYaml: ZoweYamlType;
  let cleanupDatasets: TestFile[] = []; // a list of datasets deleted after every test

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
  });
  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
    defaultCfgYaml = ZoweConfig.getDefaultsYaml();
  });

  afterEach(async () => {
    await testRunner.postTest();

    // re-created in every `init generate` based on changes to zowe yaml command...
    const jcllib: TestFile = { name: REMOTE_SYSTEM_INFO.jcllib, type: FileType.DS_NON_CLUSTER };

    // try to delete everything we know about
    await TestFileActions.deleteAll([...cleanupDatasets, jcllib]);
    cleanupDatasets = [];
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    beforeAll(async () => {
      cfgYaml = ZoweConfig.getZoweYaml();
    });

    // Cover configmgr PARMLIB validation: easy access from 'init generate' to common.isValidZoweYamlParmlib()
    it('PARMLIB negatives', async () => {
      let result;
      const cases = [
        '"PARMLIB(ZOWE.PR4285(A)"',
        '"PARMLIB(ZOWE.PR4285(A"',
        '"PARMLIB(ZOWE.PR4285(A)):PARMLIB(ZOWE.PR4285(A)"',
        '"PARMLIB(ZOWE.PR4285(A)):PARMLIB(ZOWE.PR4285(A):PARMLIB(ZOWE.PR4285(A)):PARMLIB(ZOWE.PR4285(A)"',
        '"PARMLIB(ZOWE.PR4285B)):FILE(defaults.yaml)"',
      ];

      for (const tcase of cases) {
        result = await testRunner.runZweTest(cfgYaml, `init generate --dry-run -c ${tcase}`);
        expect(result.stdout).not.toBeNull();
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(60);
      }
    });

    it('jcl header single line', async () => {
      // eslint-disable-next-line
      _.set(cfgYaml, 'zowe.setup.jcl.header', "'SOMEJOB',(0000000000)");
      const result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('jcl header multi line', async () => {
      // eslint-disable-next-line
      const longString = "LONGFIELD1,LONGFIELD2,LONGFIELD3,ANOTHER,FIELD,GOING,WAY,PAST,EIGHTY,CHARACTERS,INCLUDING,THIS";
      let jclLines = [`'SOMEJOB'`, `// (0000000000)`, longString, 'SYSAFF=SYS1'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines);
      let result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      // this is technically not valid JCL, but fits in 80 chars
      jclLines = [`'SOMEJOB'`, `//    (0000000000)`, ('//    ' + longString).slice(0, 79), '//    SYSAFF=SYS1'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines);
      result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      // with idx 0, the slice is invalid for first line. this is currently allowed by schema.
      jclLines = [longString.slice(0, 79), `//    (0000000000)`, '//    SOMEJOB', '//    SYSAFF=SYS1'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines);
      result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      // this is the right max width
      jclLines = [longString.slice(0, 80 - ('//ABCABCDE JOB '.length + 1)), `// (0000000000),`, `// 'SOMEJOB',`, '// SYSAFF=SYS1'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines);
      result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('jcl header single line length', async () => {
      // eslint-disable-next-line
      const longString = "'SOMEJOB',(0000000000),ANOTHER,FIELD,GOING,WAY,PAST,EIGHTY,CHARACTERS,INCLUDING,THIS";
      // error - line > 100 chars
      _.set(cfgYaml, 'zowe.setup.jcl.header', longString);
      let result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      // error - 81 char line
      // eslint-disable-next-line
      _.set(cfgYaml, 'zowe.setup.jcl.header', longString.slice(0, 80 - ('//ABCABCDE JOB '.length - 1)));
      result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      // OK - 80 char line
      // eslint-disable-next-line
      _.set(cfgYaml, 'zowe.setup.jcl.header', longString.slice(0, 80 - '//ABCABCDE JOB '.length));
      result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('bad ds prefix', async () => {
      cfgYaml.zowe.setup.dataset.prefix = 'SOME.DS.NOEXIST';
      const result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(143);
    });

    it('simple --dry-run', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('BAD: missing defaults.yaml', async () => {
      await testRunner.removeUssFileOrDirForTest('files/defaults.yaml');
      const result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot(); // FIXME: the snapshot indicates processing continues when it shouldn't
      expect(result.rc).not.toBe(0);
    });

    it('BAD: invalid value defaults.yaml', async () => {
      delete cfgYaml.zowe.configmgr;
      // @ts-expect-error intentionally setting an incorrect value
      defaultCfgYaml.zowe.configmgr.validation = 'WRONG_VALUE';
      const result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.rc).toBe(1);
    });

    // TODO: This test gives RC=0, but shouldn't it fail?
    it('BAD: invalid format defaults.yaml', async () => {
      // @ts-expect-error invalid yaml format
      defaultCfgYaml.zowe = '....\n somefield:\n  #another:\n' + defaultCfgYaml.zowe;
      const result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });
  });

  describe('(LONG)', () => {
    it('jcllib updates: jcl header single line', async () => {
      const header = `'SOMEJOB',REGION=0M`;
      _.set(cfgYaml, 'zowe.setup.jcl.header', header);
      const result = await testRunner.runZweTest(cfgYaml, 'init generate');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      // the jcl generated in JCLLIB should have the headers
      const localPdsPath = await TestFileActions.downloadPds(cfgYaml.zowe.setup.dataset.jcllib as string);
      const members = fs.readdirSync(localPdsPath);
      // skip Zowe STC, this shouldn't have the headers, and deprecated keyring members (to be removed in v4)
      const exceptions = /(zwe.*?stc)|(ZWEKRING)|(ZWENOKYR)/i;
      for (const member of members) {
        if (exceptions.test(member)) {
          continue;
        }
        const jclFile = path.join(localPdsPath, member);
        const jclFileContent = fs.readFileSync(jclFile, 'utf8');
        testRunner.collectTestFile(jclFile);
        expect(jclFileContent).toContain(header);
      }
      // cleanup the downloaded pds
      fs.rmSync(localPdsPath, { recursive: true });
    });

    it('jcllib updates: jcl header multi line', async () => {
      const jclLines = [`'SOMEJOB',`, `// REGION=0M`, `//* atestcomment`, '//* secondtestcomment'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines);
      const result = await testRunner.runZweTest(cfgYaml, 'init generate');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      // the jcl generated in JCLLIB should have the headers
      const localPdsPath = await TestFileActions.downloadPds(cfgYaml.zowe.setup.dataset.jcllib as string);
      const members = fs.readdirSync(localPdsPath);
      // skip Zowe STC, this shouldn't have the headers, and deprecated keyring members (to be removed in v4)
      const exceptions = /(zwe.*?stc)|(ZWEKRING)|(ZWENOKYR)/i;
      for (const member of members) {
        if (exceptions.test(member)) {
          // skip Zowe STC, this shouldn't have the headers
          continue;
        }
        const jclFile = path.join(localPdsPath, member);
        const jclFileContent = fs.readFileSync(jclFile, 'utf8');
        testRunner.collectTestFile(jclFile);
        expect(jclFileContent).toContain(jclLines.join('\n'));
      }
      // cleanup the downloaded pds
      fs.rmSync(localPdsPath, { recursive: true });
    });
  });
});
