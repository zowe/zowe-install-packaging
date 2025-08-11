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

const testSuiteName = 'feat-invalidYaml';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
  });
  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  afterEach(async () => {
    await testRunner.postTest();
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    beforeEach(async () => {
      // TODO: Replace this with an upload of __resources__/bad.yaml to zowe.test.yaml
      await testRunner.uploadZoweYaml(cfgYaml);
      await testRunner.runRaw('sed -e "s#jcllib\\:#jcllib#g" zowe.test.yaml | tee zowe.test.yaml');
    });

    it('run commands with bad config', async () => {
      const testCases = [
        { cmd: 'install', rc: 68 },
        { cmd: 'init', rc: 68 },
        { cmd: 'init apfauth', rc: 68 },
        { cmd: 'init certificate', rc: 68 },
        { cmd: 'init generate', rc: 1 },
        { cmd: 'init mvs', rc: 68 },
        { cmd: 'init security', rc: 68 },
        { cmd: 'init stc', rc: 68 },
        { cmd: 'init vsam', rc: 68 },
      ];

      for (const test of testCases) {
        const result = await testRunner.runRaw(`./bin/zwe ${test.cmd} --dry-run -c zowe.test.yaml`);
        expect(result.stdout).not.toBeNull();
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toEqual(test.rc);
      }
    });
  });
});
