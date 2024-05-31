/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { RemoteTestRunner } from '../../zos/RemoteTestRunner';
import { ZoweYaml } from '../../config/ZoweYaml';

/**
 * Make sure the test suite and remote system are working as expected
 */
const testSuiteName = 'Canary tests';
describe(testSuiteName, () => {
  let testRunner: RemoteTestRunner;
  beforeAll(() => {
    testRunner = new RemoteTestRunner('canary');
  });

  it('run echo', async () => {
    const cfgYaml = ZoweYaml.basicZoweYaml();
    cfgYaml.java.home = '/ZOWE/node/J21.0_64/';
    const result = await testRunner.runRaw('echo "hi"');
    expect(result.rc).toBe(0);
    expect(result.stdout).not.toBeNull();
    expect(result.stdout).toMatchSnapshot();
  });

  it('a test', async () => {
    const cfgYaml = ZoweYaml.basicZoweYaml();
    cfgYaml.java.home = '/ZOWE/node/J21.0_64/';
    const result = await testRunner.runZweTest(cfgYaml, '--help');
    expect(result.rc).toBe(100); // 100 is expected...
    expect(result.stdout).not.toBeNull();
    expect(result.stdout).toMatchSnapshot();
  });
});
