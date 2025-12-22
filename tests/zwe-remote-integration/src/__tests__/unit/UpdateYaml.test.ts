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
import { getZoweVersion } from '../../utils';
import { FileType, TestFile, TestFileActions } from '../../zos/TestFileActions';
import { createPds, SIMPLE_PDS_PARAMS } from '../../zos/Files';

/*
  Verify-fingerprint correctness is tested through playbook automation. It's not simple to re-create a working fingerprint file
    in this suite's remote integration environment.
*/
const testSuiteName = 'unit-updateyaml';
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
    // no node + app-server enabled = fail, no node + app-server disabled = pass
    it('update_yaml different config syntaxes', async () => {
      const testParmlib = `${cfgYaml.zowe.setup.dataset.prefix}.PRMTST`;
      const testParmCfg = `${testParmlib}(ZWECONF)`;
      const testFileCfg = await testRunner.uploadZoweYaml(cfgYaml);
      await createPds(testParmlib, SIMPLE_PDS_PARAMS);
      cleanupFiles.push({
        name: testParmlib,
        type: FileType.DS_NON_CLUSTER,
      });
      cleanupFiles.push({
        name: testFileCfg,
        type: FileType.USS_FILE,
      });
      await testRunner.uploadToDatasetForTest(ZoweConfig.render(cfgYaml), testParmCfg);
      const goodTestCases = [
        '"zowe.setup.jcl.enable" "false" "true"',
        '"zowe.setup.jcl.enable" "false" "false"',
        '"zowe.runtimeDirectory" "/a/b/c" "true"',
        '"zowe.notexist" "/a/b/c" "true"',
        '"zowe.setup.jcl.enable" "badvalue" "true"',
      ];
      // destructive; need to revert zowe.yaml after these
      // const badTestCases = ['"zowe.notexist" "/a/b/c" "false"', '"zowe.setup.jcl.enable" "badvalue" "false"'];
      const cfgFiles = [`PARMLIB(${testParmCfg})`, `FILE(${testFileCfg})`, `${testFileCfg}`];

      for (const cfgType of cfgFiles) {
        for (const tCase of goodTestCases) {
          const result = await testRunner.runRaw(`sh && \
            export ZWE_zowe_runtimeDirectory=\`pwd\` && \
            export ZWE_CLI_PARAMETER_CONFIG="${cfgType}" && \
            . ./bin/libs/index.sh && \
            update_zowe_yaml "${cfgType}" ${tCase}`);
          expect(result.cleanedStdout).toMatchSnapshot();
        }
      }
    });
  });

  describe('(LONG)', () => {});
});
