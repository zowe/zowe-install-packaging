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
import * as path from 'path';

const testSuiteName = 'feat-invalidYaml';
const yamlResourceDir = path.resolve('src', '__tests__', 'features', '__resources__');
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
  });

  afterEach(async () => {
    await testRunner.postTest();
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('run commands with bad config', async () => {
      const testYamlPath = await testRunner.uploadZoweYamlFromFile(path.resolve(yamlResourceDir, 'bad.yaml'));

      const testCases = [
        { cmd: 'install', rc: 70 },
        { cmd: 'init', rc: 70 },
        { cmd: 'init apfauth', rc: 70 },
        { cmd: 'init certificate', rc: 70 },
        { cmd: 'init generate', rc: 1 },
        { cmd: 'init mvs', rc: 70 },
        { cmd: 'init security', rc: 70 },
        { cmd: 'init stc', rc: 70 },
        { cmd: 'init vsam', rc: 70 },
      ];

      for (const test of testCases) {
        const result = await testRunner.runRaw(`./bin/zwe ${test.cmd} --dry-run -c ${testYamlPath}`);
        expect(result.stdout).not.toBeNull();
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toEqual(test.rc);
      }
    });
  });
});
