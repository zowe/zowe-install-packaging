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
import { REMOTE_SYSTEM_INFO } from '../../config/TestConfig';
import _ from 'lodash';
import { getZoweVersion } from '../../utils';
import { FileType, TestFile, TestFileActions } from '../../zos/TestFileActions';

/*
  Verify-fingerprint correctness is tested through playbook automation. It's not simple to re-create a working fingerprint file
    in this suite's remote integration environment.
*/
const testSuiteName = 'support-base';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType = ZoweConfig.getZoweYaml();
  let cleanupFiles: TestFile[] = [];
  const fingerprintDir = `${cfgYaml.zowe.runtimeDirectory}/fingerprint`;

  async function makeDummyFingerpints(dir: string) {
    const customHashes = `${dir}/RefRuntimeHash-${getZoweVersion()}.txt`;
    await testRunner.runRaw(`mkdir -p ${dir}`);
    await testRunner.runRaw(`echo "Dummy" > ${customHashes}`);
  }

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
    const cleanSecurityManager = (input: string) => {
      return input.replaceAll(/TSS|ACF2|RACF/gi, 'ESMT'); // ESM TEST
    };
    testRunner.addCleanFn(cleanSecurityManager);
  });
  beforeEach(async () => {
    cfgYaml = ZoweConfig.getZoweYaml();
    await makeDummyFingerpints(fingerprintDir);
    cleanupFiles.push({
      name: `${fingerprintDir}`,
      type: FileType.USS_DIR,
    });
  });

  afterEach(async () => {
    await TestFileActions.deleteAll(cleanupFiles);
    await testRunner.postTest();
    cleanupFiles = [];
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('support with everything enabled', async () => {
      _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
      // output support pax in fingerprint dir, we're not getting a passing fingerprint check anyway
      const result = await testRunner.runZweTest(cfgYaml, `support --target-dir ${fingerprintDir}`);
      // don't snapshot this since it contains a lot of system information, instead key on specific details:
      //   -- z/OSMF is active and curl worked
      //   -- Fingerprints failed (we supply a dummy)
      //   -- The support package is created
      expect(result.stdout).not.toBeNull();
      expect(result.stdout.includes('Successfully checked z/OSMF is available')).toBe(true);
      expect(result.stdout.includes('ZWEL0181E: Failed to verify Zowe file fingerprints')).toBe(true);
      expect(result.stdout.includes('Zowe support package is generated')).toBe(true);
      expect(result.rc).toBe(0);
    });

    // no node + app-server enabled = fail, no node + app-server disabled = pass
    it('disable node, app-server', async () => {
      let result = await testRunner.runZweTest(cfgYaml, `support --target-dir ${fingerprintDir}`);
      expect(result.stdout).not.toBeNull();
      expect(result.stdout.includes('Error ZWEL0121E: Cannot find node.')).toBe(true);
      expect(result.rc).toBe(121);

      cfgYaml.components['app-server'].enabled = false;
      result = await testRunner.runZweTest(cfgYaml, `support --target-dir ${fingerprintDir}`);
      expect(result.stdout.includes('Successfully checked z/OSMF is available')).toBe(true);
      expect(result.stdout.includes('ZWEL0181E: Failed to verify Zowe file fingerprints')).toBe(true);
      expect(result.stdout.includes('Zowe support package is generated')).toBe(true);
      expect(result.rc).toBe(0);
    });

    it('bad z/osmf host and port', async () => {
      cfgYaml.zOSMF.port = Number(cfgYaml.zOSMF.port) + 1;
      _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
      let result = await testRunner.runZweTest(cfgYaml, `support --target-dir ${fingerprintDir}`);
      expect(result.stdout).not.toBeNull();
      expect(result.stdout.includes('No response code from z/OSMF server.')).toBe(true);
      expect(result.rc).toBe(0);

      cfgYaml.zOSMF.host = 'does-not.exist.com';
      result = await testRunner.runZweTest(cfgYaml, `support --target-dir ${fingerprintDir}`);
      expect(result.stdout.includes('No response code from z/OSMF server.')).toBe(true);
      expect(result.rc).toBe(0);
    });
  });

  describe('(LONG)', () => {});
});
