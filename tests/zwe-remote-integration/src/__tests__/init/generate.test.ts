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
import { sleep } from '../../utils';

const testSuiteName = 'init-generate';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let defaultCfgYaml: ZoweYamlType;
  let cleanupFiles: TestFile[] = []; // a list of datasets deleted after every test

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
    await TestFileActions.deleteAll([...cleanupFiles, jcllib]);
    cleanupFiles = [];
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
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines.join('\n'));
      let result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(144);

      // this is technically not valid JCL, but fits in 80 chars
      jclLines = [`'SOMEJOB'`, `//    (0000000000)`, ('//    ' + longString).slice(0, 79), '//    SYSAFF=SYS1'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines.join('\n'));
      result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      // with idx 0, the slice is invalid for first line. This was allowed by prior implementation, but is an error now
      jclLines = [longString.slice(0, 79), `//    (0000000000)`, '//    SOMEJOB', '//    SYSAFF=SYS1'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines.join('\n'));
      result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(144);

      // this is the right max width
      jclLines = [longString.slice(0, 80 - ('//ABCABCDE JOB '.length + 1)), `// (0000000000),`, `// 'SOMEJOB',`, '// SYSAFF=SYS1'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines.join('\n'));
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
      expect(result.rc).toBe(144);

      // error - 81 char line
      // eslint-disable-next-line
      _.set(cfgYaml, 'zowe.setup.jcl.header', longString.slice(0, 80 - ('//ABCABCDE JOB '.length - 1)));
      result = await testRunner.runZweTest(cfgYaml, 'init generate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(144);

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

  describe('FLAKY', () => {
    it('interrupt generate commands', async () => {
      // First case: cancel and purge

      // we have ~30 seconds to cancel the running job
      let deferredResult = testRunner.runZweTest(cfgYaml, 'init generate --allow-overwrite');
      // wait for zwegener to be submitted
      await sleep(6000);
      // TODO: this can capture other ZWEGENER tasks running on the system? change jcl name before submission?
      let jobid = await testRunner.runRaw(
        `./bin/utils/zowex job list --rfc | awk -F, 'match($3, "ZWEGENER") && match($4, "ACTIVE") { print $1 }'`,
      );
      let runningJob = jobid.stdout.trim();
      console.log(`Found running job: ${runningJob}`);
      await testRunner.runRaw(`./bin/utils/zowex job cancel ${runningJob}`);
      await testRunner.runRaw(`./bin/utils/zowex job delete ${runningJob}`);
      let genResult = await deferredResult;
      expect(genResult.cleanedStdout).toMatchSnapshot();

      // Second case: cancel

      deferredResult = testRunner.runZweTest(cfgYaml, 'init generate --allow-overwrite');
      // wait for zwegener to be submitted
      await sleep(6000);
      // TODO: this can capture other ZWEGENER tasks running on the system? change jcl name before submission?
      jobid = await testRunner.runRaw(
        `./bin/utils/zowex job list --rfc | awk -F, 'match($3, "ZWEGENER") && match($4, "ACTIVE") { print $1 }'`,
      );
      runningJob = jobid.stdout.trim();
      console.log(`Found running job: ${runningJob}`);
      await testRunner.runRaw(`./bin/utils/zowex job cancel ${runningJob}`);
      genResult = await deferredResult;
      expect(genResult.cleanedStdout).toMatchSnapshot();
    });
  });

  describe('(LONG)', () => {
    function expectStcSTDEnvHasContinuations(stcContent: string) {
      let stdEnvPassed = false;
      stcContent.split('\n').forEach((line) => {
        if (line.startsWith('//STDENV')) {
          stdEnvPassed = true;
        }
        if (stdEnvPassed) {
          expect(line.length <= 73);
          if (line.length === 73) {
            expect(line.endsWith(`\\`)).toBe(true);
          }
        }
      });
    }

    /**
     * This test cannot accurately capture the output of ZWESLSTC as a snapshot, because the
     *  test directory may vary from system to system which changes the output. We check that the correct
     *  config choices are ordered in the final ZWESLSTC and that the lonest lines in STDENV end with backslash
     */
    it('test adversarial paths and concatenations', async () => {
      const MAX_DIR_LEN = 255; // USS restriction
      const MAX_TOTAL_PATH_LEN = 261; // unknown REXX submit() restriction...no doc. related to lrecl?

      const EVIL_DIR_LEN = MAX_TOTAL_PATH_LEN - REMOTE_SYSTEM_INFO.ussTestDir.length - '//zowe.test.yaml'.length - 'FILE '.length + 1;
      if (EVIL_DIR_LEN >= MAX_DIR_LEN) {
        // idk yet - shouldn't happen
        throw new Error(`Can't run this test`);
      }
      const goodDir = `${REMOTE_SYSTEM_INFO.ussTestDir}/${'a'.repeat(EVIL_DIR_LEN - 1)}`;
      const evilDir = `${REMOTE_SYSTEM_INFO.ussTestDir}/${'a'.repeat(EVIL_DIR_LEN)}`;
      await testRunner.runRaw(`mkdir -p ${goodDir}`, REMOTE_SYSTEM_INFO.ussTestDir);
      await testRunner.runRaw(`mkdir -p ${evilDir}`, REMOTE_SYSTEM_INFO.ussTestDir);
      cleanupFiles.push(
        {
          name: evilDir,
          type: FileType.USS_DIR,
        },
        {
          name: goodDir,
          type: FileType.USS_DIR,
        },
      );
      const dupCfg = ZoweConfig.getZoweYaml();
      const parmMemberOne = `${cfgYaml.zowe.setup.dataset.parmlib}(ZWECFG01)`;
      const parmMemberTwo = `${cfgYaml.zowe.setup.dataset.parmlib}(ZWECFG02)`;
      delete dupCfg.zowe.setup.jcl; // avoid problems with arrays being duplicated through cfgYaml
      delete dupCfg.zowe.sysMessages;
      delete dupCfg.zowe.externalDomains;
      await testRunner.uploadToDatasetForTest(ZoweConfig.render(dupCfg), parmMemberOne);
      await testRunner.uploadToDatasetForTest(ZoweConfig.render(dupCfg), parmMemberTwo);

      await testRunner.uploadZoweYaml(dupCfg, false, evilDir);
      await testRunner.uploadDefaultsYaml(defaultCfgYaml, evilDir);

      await testRunner.uploadZoweYaml(dupCfg, false, goodDir);
      await testRunner.uploadDefaultsYaml(defaultCfgYaml, goodDir);

      let result = await testRunner.runRaw(
        `./bin/zwe init generate --allow-overwrite -c "PARMLIB(${parmMemberOne}):PARMLIB(${parmMemberTwo}):FILE(${evilDir}/zowe.test.yaml):FILE(${evilDir}/defaults.yaml)"`,
      );

      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      result = await testRunner.runRaw(`./bin/zwe init generate --allow-overwrite -c ${evilDir}/zowe.test.yaml`);

      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      result = await testRunner.runRaw(`./bin/zwe init generate --allow-overwrite -c ${goodDir}/zowe.test.yaml`);

      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runRaw(
        `./bin/zwe init generate --allow-overwrite -c "PARMLIB(${parmMemberOne}):PARMLIB(${parmMemberTwo}):FILE(${goodDir}/zowe.test.yaml):FILE(${goodDir}/defaults.yaml)"`,
      );

      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      let generatedStc = await testRunner.downloadMaskedPdsMember(`${cfgYaml.zowe.setup.dataset.jcllib}(ZWESLSTC)`);
      await testRunner.collectTestFile(generatedStc);
      let stcContents = fs.readFileSync(generatedStc, 'utf8');
      expect(stcContents.includes(`CONFIG=PARMLIB(${parmMemberOne})`));
      expect(stcContents.includes(`PARMLIB(${parmMemberTwo})`));
      expectStcSTDEnvHasContinuations(stcContents);

      result = await testRunner.runRaw(
        `./bin/zwe init generate --allow-overwrite -c "FILE(${goodDir}/zowe.test.yaml):FILE(${goodDir}/defaults.yaml):PARMLIB(${parmMemberOne}):PARMLIB(${parmMemberTwo})"`,
      );

      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      generatedStc = await testRunner.downloadMaskedPdsMember(`${cfgYaml.zowe.setup.dataset.jcllib}(ZWESLSTC)`);
      await testRunner.collectTestFile(generatedStc);
      stcContents = fs.readFileSync(generatedStc, 'utf8');
      expect(stcContents.includes(`CONFIG=PARMLIB(${parmMemberOne})`));
      expect(stcContents.includes(`PARMLIB(${parmMemberTwo})`));
      expectStcSTDEnvHasContinuations(stcContents);

      result = await testRunner.runRaw(
        `./bin/zwe init generate --allow-overwrite -c "FILE(${goodDir}/zowe.test.yaml):PARMLIB(${parmMemberTwo})"`,
      );

      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      generatedStc = await testRunner.downloadMaskedPdsMember(`${cfgYaml.zowe.setup.dataset.jcllib}(ZWESLSTC)`);
      await testRunner.collectTestFile(generatedStc);
      stcContents = fs.readFileSync(generatedStc, 'utf8');
      expect(stcContents.includes(`CONFIG=FILE(${goodDir.substring(0, 71 - 12)}`));
      expect(stcContents.includes(`PARMLIB(${parmMemberTwo})`));
      expectStcSTDEnvHasContinuations(stcContents);
    }, 400000);

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
      const jclLines = [`'SOMEJOB',`, `//   REGION=0M`, `//* atestcomment`, '//* secondtestcomment'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines.join('\n'));
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

    it('jcllib updates: jcl header multi line without block strings', async () => {
      const jclLines = [`'SOMEJOB',`, `//   REGION=0M`, `//* atestcomment`, '//* secondtestcomment'];
      _.set(cfgYaml, 'zowe.setup.jcl.header', jclLines.join('\n'));
      testRunner.setYamlRenderOptions({ blockQuote: false });
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
