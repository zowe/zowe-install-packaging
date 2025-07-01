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
import * as fs from 'fs-extra';
import * as yaml from 'yaml';

const testSuiteName = 'compare-zwe-output-with-launcher';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let defaultCfgYaml: ZoweYamlType;

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
    defaultCfgYaml = ZoweConfig.getDefaultsYaml();
    const cleanSecurityManager = (input: string) => {
      return input.replaceAll(/TSS|ACF2|RACF/gi, 'ESMT'); // ESM TEST
    };
    testRunner.addCleanFn(cleanSecurityManager);
  });
  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
    defaultCfgYaml = ZoweConfig.getDefaultsYaml();
  });

  afterEach(async () => {
    await testRunner.postTest();
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    it('compare .zowe-merged.yaml created by launcher and zwe', async () => {
      const defaultsUpl = await testRunner.uploadDefaultsYaml(defaultCfgYaml);
      const zyUpl = await testRunner.uploadZoweYaml(cfgYaml);

      const launcherRes = await testRunner.runRaw(` 
            export RUNTIME_DIRECTORY=${cfgYaml.zowe.runtimeDirectory} && \
            export CONFIG='FILE(${zyUpl}):FILE(${defaultsUpl})' && \
            export ZLDEBUG='ON' && \
            ${cfgYaml.zowe.runtimeDirectory}/components/launcher/bin/zowe_launcher ''`);

      // this is an intentionally invalid zowe_launcher run - create env configs and then exit with an error
      expect(launcherRes.rc).toBe(8);

      const launchZoweMerged = await testRunner.downloadMaskedUssFilesMatching('*.yaml', `${cfgYaml.zowe.workspaceDirectory}/.env/`);
      expect(launchZoweMerged.length).toBe(1);
      testRunner.collectTestFile(launchZoweMerged[0]);

      const prepRes = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(prepRes.rc).toBe(0);

      const zweZoweMerged = await testRunner.downloadMaskedUssFilesMatching('*.yaml', `${cfgYaml.zowe.workspaceDirectory}/.env/`);
      expect(zweZoweMerged.length).toBe(1);
      testRunner.collectTestFile(zweZoweMerged[0]);

      // track changes to merged yaml files generally
      const launchMergedYaml = fs.readFileSync(launchZoweMerged[0], 'utf8');
      const zweMergedYaml = fs.readFileSync(zweZoweMerged[0], 'utf8');
      expect(launchMergedYaml).toMatchSnapshot();
      expect(zweMergedYaml).toMatchSnapshot();

      // the merged yaml files should be equal or equivalent

      const launchYaml: ZoweYamlType = yaml.parse(launchMergedYaml);
      const zweYaml: ZoweYamlType = yaml.parse(zweMergedYaml);

      expect(launchYaml).toEqual(zweYaml);

      // try to extract json from launcher stdout
      const regex = /INFO ZWEL0018I.*?(\{.*\}).*?mkey='/gims;
      const matches = regex.exec(launcherRes.cleanedStdout);
      expect(matches.length).toBe(2);
      const jsonGroup = matches[1];
      expect(jsonGroup).not.toBeNull();
      const yamlFormat = yaml.parse(jsonGroup);
      expect(yamlFormat).toEqual(launchYaml);
    });
  });
});
