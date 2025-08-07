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
import { FileType, TestFileActions, TestFile } from '../../zos/TestFileActions';

const testSuiteName = 'init-cert';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let cleanupFiles: TestFile[] = []; // a list of datasets deleted after every test

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
    expect.getState().currentTestName = 'before-all-cert';
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
    await TestFileActions.deleteAll(cleanupFiles);
    cleanupFiles = [];
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('cert missing zowe.yaml vars', async () => {
      cfgYaml.zowe.setup.certificate.type = 'JCERACFKS';
      cfgYaml.zowe.setup.certificate.keyring = { name: 'safkeyring://some.keyring' };
      cfgYaml.zowe.setup.dataset.jcllib = 'DOES.NOT.EXIST'; // only an error when !pkcs12
      let result = await testRunner.runZweTest(cfgYaml, 'init certificate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(63);

      cfgYaml = ZoweConfig.getZoweYaml(); // reset
      delete cfgYaml.zowe.setup.dataset.prefix;
      result = await testRunner.runZweTest(cfgYaml, 'init certificate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);

      cfgYaml = ZoweConfig.getZoweYaml();
      cfgYaml.zowe.setup.certificate.type = null;
      result = await testRunner.runZweTest(cfgYaml, 'init certificate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(201);
    });
  });

  describe('(LONG)', () => {
    it('passing init', async () => {
      cfgYaml.zowe.verifyCertificates = 'NONSTRICT';
      const result = await testRunner.runZweTest(cfgYaml, 'init certificate');
      cleanupFiles.push(
        {
          // @ts-expect-error incomplete schema
          name: cfgYaml.zowe.setup.certificate.pkcs12.directory + '/local_ca/',
          type: FileType.USS_DIR,
        },
        {
          // @ts-expect-error incomplete schema
          name: cfgYaml.zowe.setup.certificate.pkcs12.directory + '/localhost/',
          type: FileType.USS_DIR,
        },
      );
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('cert bad hostname', async () => {
      cfgYaml.zowe.useConfigmgr = true;
      cfgYaml.zOSMF.host = 'doesnt-exist.anywhere.cloud';
      const result = await testRunner.runZweTest(cfgYaml, 'init certificate');
      cleanupFiles.push(
        {
          // @ts-expect-error incomplete schema
          name: cfgYaml.zowe.setup.certificate.pkcs12.directory + '/local_ca/',
          type: FileType.USS_DIR,
        },
        {
          // @ts-expect-error incomplete schema
          name: cfgYaml.zowe.setup.certificate.pkcs12.directory + '/localhost/',
          type: FileType.USS_DIR,
        },
      );
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(170);
    });
  });
});
