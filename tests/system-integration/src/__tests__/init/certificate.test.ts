/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { REMOTE_SYSTEM_INFO, TEST_COLLECT_SPOOL } from '../../config/TestConfig';
import ZoweYamlType from '../../types/ZoweYamlType';
import { RemoteTestRunner } from '../../zos/RemoteTestRunner';
import { ZoweYaml } from '../../config/ZoweYaml';
import { DatasetType, TestAwareFiles, TestManagedDataset } from '../../zos/TestAwareFiles';

const testSuiteName = 'init-cert';
describe(testSuiteName, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let cleanupDatasets: TestManagedDataset[] = []; // a list of datasets deleted after every test

  beforeAll(() => {
    testRunner = new RemoteTestRunner('init-cert');
  });
  beforeEach(() => {
    cfgYaml = ZoweYaml.basicZoweYaml();
  });

  afterEach(async () => {
    if (TEST_COLLECT_SPOOL) {
      await testRunner.collectSpool();
    }
    // re-created in every `init` subcommand based on changes to zowe yaml command...
    const jcllib: TestManagedDataset = { name: REMOTE_SYSTEM_INFO.jcllib, type: DatasetType.NON_CLUSTER };

    // try to delete everything we know about
    await TestAwareFiles.deleteAll([...cleanupDatasets, jcllib]);
    cleanupDatasets = [];
  });

  it('cert disable cfgmgr', async () => {
    cfgYaml.zowe.useConfigmgr = false;
    const result = await testRunner.runZweTest(cfgYaml, 'init certificate');
    expect(result.stdout).not.toBeNull();
    expect(result.cleanedStdout).toMatchSnapshot();
    expect(result.rc).toBe(231); // 231 is expected error code...?
  });

  it('cert enable cfgmgr', async () => {
    cfgYaml.zowe.useConfigmgr = true;
    const result = await testRunner.runZweTest(cfgYaml, 'init certificate');
    expect(result.stdout).not.toBeNull();
    expect(result.cleanedStdout).toMatchSnapshot();
    expect(result.rc).toBe(231); // 231 is expected error code...?
  }, 180000);
  /*
  it('cert bad ds prefix', async () => {
    cfgYaml.zowe.setup.dataset.prefix = 'ZOWEAD6.ZWETEST.NOEXIST';
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
