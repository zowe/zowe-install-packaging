/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { RemoteTestRunner } from '../RemoteTestRunner';
import { ZoweYaml } from '../ZoweYaml';

const testSuiteName = 'Dummy tests';
describe(testSuiteName, () => {
  beforeEach(() => {});

  it('run echo', async () => {
    const testRunner = new RemoteTestRunner();

    console.log('heres a log');
    const cfgYaml = ZoweYaml.basicZoweYaml();
    cfgYaml.java.home = '/ZOWE/node/J21.0_64/';
    const result = await testRunner.runRaw('echo "hi"');
    console.log(result);
    console.log(JSON.stringify(result));
    expect(result.rc).toBe(0); // 100 is expected...
    expect(result.stdout).not.toBeNull();
    expect(result.stdout).toMatchSnapshot();

    const result2 = await testRunner.runRaw('cat /u/zowead3/.profile');
    console.log(result2);
    console.log(JSON.stringify(result2));
    expect(result2.rc).toBe(0); // 100 is expected...
    expect(result2.stdout).not.toBeNull();
    expect(result2.stdout).toMatchSnapshot();
  });

  it('a test', async () => {
    const testRunner = new RemoteTestRunner();
    console.log('heres a log');
    const cfgYaml = ZoweYaml.basicZoweYaml();
    cfgYaml.java.home = '/ZOWE/node/J21.0_64/';
    const result = await testRunner.runTest(cfgYaml, '--help');
    console.log(result);
    console.log(JSON.stringify(result));
    expect(result.rc).toBe(100); // 100 is expected...
    expect(result.stdout).not.toBeNull();
    expect(result.stdout).toMatchSnapshot();
  });
});
