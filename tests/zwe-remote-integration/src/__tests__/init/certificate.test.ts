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
import { FileType, TestFileActions, TestFile } from '../../zos/TestFileActions';
import { REMOTE_SYSTEM_INFO, REPO_ROOT_DIR } from '../../config/TestConfig';
import * as path from 'path';
import _ from 'lodash';

const testSuiteName = 'init-cert';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let cleanupFiles: TestFile[] = []; // a list of datasets deleted after every test

  const localScenarioDir: string = path.resolve(REPO_ROOT_DIR, 'files', 'examples', 'setup', 'certificate');
  const remoteScenarioDir: string = path.resolve(REMOTE_SYSTEM_INFO.ussTestDir, 'files', 'examples', 'setup', 'certificate');
  const scenarioYamls: string[] = ['scenario-1.yaml', 'scenario-2.yaml', 'scenario-3.yaml', 'scenario-4.yaml', 'scenario-5.yaml'];
  const remotePkcs12Dir: string = `${REMOTE_SYSTEM_INFO.ussTestDir}/pkcs12`;

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
    expect.getState().currentTestName = 'before-all-cert';
    const result = await testRunner.runZweTest(cfgYaml, 'init generate --allow-overwrite');
    expect(result.stdout).not.toBeNull();
    expect(result.rc).toBe(0);
    await testRunner.postTest();
  });
  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFileActions.deleteAll(cleanupFiles);
    cleanupFiles = [];
  });

  afterAll(() => {
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    /**
     * Runs all 5 init certificate scenarios. PKCS12 scenarios are "live" and certificate scenarios are dry-run.
     *
     * After scenario 1, this uses the output keystore as input to scenario 2.
     *
     */
    it('run each scenario', async () => {
      const keyringScenarios = scenarioYamls.slice(2);
      const scenarioSettings = {
        'scenario-1.yaml': {
          'zowe.setup.certificate.pkcs12.directory': remotePkcs12Dir,
        },
        'scenario-2.yaml': {
          'zowe.setup.certificate.pkcs12.directory': remotePkcs12Dir + '_scen2',
          // generated in step 1
          'zowe.setup.certificate.pkcs12.import.keystore': remotePkcs12Dir + '/localhost/localhost.keystore.p12',
          'zowe.setup.certificate.pkcs12.import.password': 'password',
          'zowe.setup.certificate.pkcs12.import.alias': 'localhost',
        },
        'scenario-3.yaml': {},
        'scenario-4.yaml': {},
        'scenario-5.yaml': {},
      };

      let testYaml = ZoweConfig.loadAndOverlay(cfgYaml, localScenarioDir, 'scenario-1.yaml');
      for (const setting of Object.entries(scenarioSettings['scenario-1.yaml'])) {
        _.set(testYaml, setting[0], setting[1]);
      }
      let result = await testRunner.runZweTest(testYaml, 'init certificate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).not.toBe(0);

      testYaml = ZoweConfig.loadAndOverlay(cfgYaml, localScenarioDir, 'scenario-2.yaml');
      for (const setting of Object.entries(scenarioSettings['scenario-2.yaml'])) {
        _.set(testYaml, setting[0], setting[1]);
      }
      result = await testRunner.runZweTest(testYaml, 'init certificate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).not.toBe(0);

      await TestFileActions.deleteAll([
        {
          name: remotePkcs12Dir,
          type: FileType.USS_DIR,
        },
        {
          name: remotePkcs12Dir + '_scen2',
          type: FileType.USS_DIR,
        },
      ]);

      for (const krScenario of keyringScenarios) {
        testYaml = ZoweConfig.loadAndOverlay(cfgYaml, localScenarioDir, krScenario);
        // @ts-expect-error incomplete schema
        for (const setting of Object.entries(scenarioSettings[krScenario])) {
          _.set(testYaml, setting[0], setting[1]);
        }
        result = await testRunner.runZweTest(testYaml, 'init certificate --dry-run');
        expect(result.stdout).not.toBeNull();
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).not.toBe(0);
      }
    }, 500000);

    it('cert missing zowe.yaml vars', async () => {
      cfgYaml = ZoweConfig.loadAndOverlay(cfgYaml, localScenarioDir, scenarioYamls[0]);
      cfgYaml.zowe.setup.certificate.type = 'JCERACFKS';
      cfgYaml.zowe.setup.certificate.keyring = { name: 'safkeyring://some.keyring' };
      cfgYaml.zowe.setup.dataset.jcllib = 'DOES.NOT.EXIST'; // only an error when !pkcs12
      let result = await testRunner.runZweTest(cfgYaml, 'init certificate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(63);

      cfgYaml = ZoweConfig.getZoweYaml(); // reset
      cfgYaml = ZoweConfig.loadAndOverlay(cfgYaml, localScenarioDir, scenarioYamls[0]);
      delete cfgYaml.zowe.setup.dataset.prefix;
      result = await testRunner.runZweTest(cfgYaml, 'init certificate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(157);

      cfgYaml = ZoweConfig.getZoweYaml();
      cfgYaml = ZoweConfig.loadAndOverlay(cfgYaml, localScenarioDir, scenarioYamls[0]);
      cfgYaml.zowe.setup.certificate.type = null;
      result = await testRunner.runZweTest(cfgYaml, 'init certificate --dry-run');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(70);
    });
  });

  describe('(LONG)', () => {
    const defaultKeystoreLocations: TestFile[] = [
      {
        name: `${remotePkcs12Dir}/local_ca/`,
        type: FileType.USS_DIR,
      },
      {
        name: `${remotePkcs12Dir}/localhost/`,
        type: FileType.USS_DIR,
      },
    ];

    // run during beforeEach in case a test abended and system isn't clean
    beforeEach(async () => {
      cfgYaml = ZoweConfig.loadAndOverlay(cfgYaml, localScenarioDir, scenarioYamls[0]);
      // @ts-expect-error incomplete schema
      cfgYaml.zowe.setup.certificate.pkcs12.directory = remotePkcs12Dir;
      await TestFileActions.deleteAll(defaultKeystoreLocations);
    });

    afterEach(async () => {
      await TestFileActions.deleteAll(defaultKeystoreLocations);
    });

    it('cert ways to use scenario.yaml', async () => {
      cfgYaml.zowe.verifyCertificates = 'NONSTRICT';
      let result = await testRunner.runZweTest(cfgYaml, 'init certificate');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
      const remoteCfgYaml = await testRunner.uploadZoweYaml(cfgYaml);
      result = await testRunner.runZweTest(
        cfgYaml,
        `init certificate -c "FILE(${remoteScenarioDir}/${scenarioYamls[0]}):FILE("${remoteCfgYaml})"`,
      );
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      await testRunner.runRaw(`cat ${remoteScenarioDir}/${scenarioYamls[0]} >> ${remoteCfgYaml}`);

      result = await testRunner.runZweTest(cfgYaml, 'init certificate');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('passing init', async () => {
      cfgYaml.zowe.verifyCertificates = 'NONSTRICT';
      const result = await testRunner.runZweTest(cfgYaml, 'init certificate');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('cert bad hostname', async () => {
      cfgYaml.zowe.useConfigmgr = true;
      cfgYaml.zOSMF.host = 'doesnt-exist.anywhere.cloud';
      const result = await testRunner.runZweTest(cfgYaml, 'init certificate');
      expect(result.stdout).not.toBeNull();
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(170);
    });
  });
});
