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

const testSuiteName = 'init-cert';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  const cleanupFiles: TestFile[] = []; // a list of datasets deleted after every test

  beforeAll(() => {
    testRunner = new RemoteTestRunner(testSuiteName);
  });
  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFileActions.deleteAll(cleanupDatasets);
    cleanupDatasets = [];
  });

  describe('(SHORT)', () => {
    beforeAll(() => {
      testRunner.runZweTest(cfgYaml, 'init generate');
    });

    it('cert dry-run', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init certificate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(231); // 231 is expected error code...?
    });

    /*
    it('cert bad ds prefix', async () => {
      cfgYaml.zowe.setup.dataset.prefix = 'ZOWEAD3.ZWETEST.NOEXIST';
      const result = await testRunner.runZweTest(cfgYaml, 'init certificate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(231);
    });

    it('cert simple --dry-run', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init certificate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0); // 60 is expected...
    });

    /* it('apf security-dry-run', async () => {
      const result = await testRunner.runZweTest(cfgYaml, 'init apfauth --security-dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0); // 60 is expected...  });
    });*/
  });

  describe('(LONG)', () => {
    it('cert bad hostname', async () => {
      cfgYaml.zowe.useConfigmgr = true;
      cfgYaml.zOSMF.host = 'doesnt-exist.anywhere.cloud';
      const result = await testRunner.runZweTest(cfgYaml, 'init certificate');
      cleanupFiles.push(
        {
          name: cfgYaml.zowe.setup.certificate.pkcs12.directory + '/local_ca/',
          type: FileType.USS_DIR,
        },
        {
          name: cfgYaml.zowe.setup.certificate.pkcs12.directory + '/localhost/',
          type: FileType.USS_DIR,
        },
      );
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(231); // 231 is expected error code...?
    });
  });
});
