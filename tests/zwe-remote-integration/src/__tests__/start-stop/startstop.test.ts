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
import * as path from 'path';

const testSuiteName = 'start-stop';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  const resourcesDir = path.resolve('src', '__tests__', 'start-stop', '__resources__');

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
    const cleanSecurityManager = (input: string) => {
      return input.replaceAll(/TSS|ACF2|RACF/gi, 'ESMT'); // ESM TEST
    };
    testRunner.addCleanFn(cleanSecurityManager);
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

  describe('(LONG)', () => {
    it('start stop normal submission', async () => {
      let result = await testRunner.runZweTest(cfgYaml, 'start');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      result = await testRunner.runZweTest(cfgYaml, 'stop');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('startstop sdsf disabled', async () => {
      const noSdsfRex = path.resolve(resourcesDir, 'noSDSF.rex');
      await testRunner.uploadUssFileForTest(noSdsfRex, 'bin/utils/getSDSF.rex', { binary: false, mode: 0o755 });

      let result = await testRunner.runZweTest(cfgYaml, 'start');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(165);

      result = await testRunner.runZweTest(cfgYaml, 'stop');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(166);
    });
  });
});
