/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import _ from 'lodash';
import { ZoweConfig } from '../../config/ZoweConfig';
import ZoweYamlType from '../../config/ZoweYamlType';
import { RemoteTestRunner } from '../../zos/RemoteTestRunner';
import { TestFile, TestFileActions } from '../../zos/TestFileActions';

const testSuiteName = 'zwe-validate-commands';
describe(`${testSuiteName}`, () => {
  let cfgYaml: ZoweYamlType;
  let testRunner: RemoteTestRunner;
  let cleanupDatasets: TestFile[] = []; // a list of datasets deleted after every test

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
  });
  beforeEach(() => {
    cfgYaml = ZoweConfig.getZoweYaml();
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFileActions.deleteAll(cleanupDatasets);
    cleanupDatasets = [];
  });

  afterAll(async () => {
    await testRunner.uploadDefaultsYaml(ZoweConfig.getDefaultsYaml(), undefined, true);
    testRunner.shutdown();
  });

  describe('(SHORT)', () => {
    describe('_(PORT)', () => {
      beforeEach(async () => {
        for (const component of Object.values(cfgYaml.components)) {
          if (component.port) {
            component.port = (Number(component.port) + 15000) % 65535;
          }
        }
      });

      it('negative component test cases', async () => {
        cfgYaml.components.zss.enabled = false; // disable for test
        // eslint-disable-next-line quotes
        const componentCases = ['', 'app-servr', 'noexist', 'null', null, 'zss', "''", '""'];
        for (const component of componentCases) {
          const result = await testRunner.runZweTest(cfgYaml, `validate port bind -o ${component}`);
          expect(`case: ${component}\n${result.cleanedStdout}`).toMatchSnapshot();
          expect(result.rc).toBe(0); // quitOnError = false from cmd line, RC=0 w/ error text
        }
      });

      it('test port priority', async () => {
        // easier to see ports printed in a failure
        _.set(cfgYaml, 'zowe.network.server.listenAddresses', ['8.8.8.8']);
        let result = await testRunner.runZweTest(cfgYaml, 'validate port bind');
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);
        // set a different port for apiml, should override gateway port
        cfgYaml.components.apiml.port = Number(cfgYaml.components.gateway.port) - 1;
        result = await testRunner.runZweTest(cfgYaml, 'validate port bind');
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);
      });

      it('validate port bind', async () => {
        let result = await testRunner.runZweTest(cfgYaml, 'validate port bind');
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);

        cfgYaml.components.apiml.enabled = false;
        result = await testRunner.runZweTest(cfgYaml, 'validate port bind');
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);
      });

      it('custom listen addresses', async () => {
        const badAddress = '8.8.8.8'; // bad listen address, google's dns
        const originalAddress = '0.0.0.0'; // hardcoded default in port bind and servers
        for (const apimlModulithSetting of [true, false]) {
          cfgYaml.components.apiml.enabled = apimlModulithSetting;
          // RC is always 0 so long as the checks run. When invoked by internal start prepare, then it respects 'zowe.launchScript.startupChecks'
          _.set(cfgYaml, 'zowe.network.server.listenAddresses', [badAddress]);
          let result = await testRunner.runZweTest(cfgYaml, 'validate port bind');
          expect(result.cleanedStdout).toMatchSnapshot();
          expect(result.rc).toBe(0);

          _.set(cfgYaml, 'components.zss.zowe.network.server.listenAddresses', [originalAddress]);
          result = await testRunner.runZweTest(cfgYaml, 'validate port bind'); // one service should pass
          expect(result.cleanedStdout).toMatchSnapshot();
          expect(result.rc).toBe(0);

          _.set(cfgYaml, 'components.zss.zowe.network.server.listenAddresses', [badAddress]);
          _.set(cfgYaml, 'zowe.network.server.listenAddresses', [originalAddress]);
          result = await testRunner.runZweTest(cfgYaml, 'validate port bind');
          expect(result.cleanedStdout).toMatchSnapshot();
          expect(result.rc).toBe(0);
        }
      });

      it('validate port bind for specific components', async () => {
        const components = Object.keys(cfgYaml.components);
        for (const apimlModulithSetting of [true, false]) {
          cfgYaml.components.apiml.enabled = apimlModulithSetting;
          for (const component of components) {
            const result = await testRunner.runZweTest(cfgYaml, `validate port bind -o ${component}`);
            expect(result.cleanedStdout).toMatchSnapshot();
            expect(result.rc).toBe(0);
          }
        }
      });
    });

    it('config validate alias', async () => {
      testRunner.addCleanFn((output) => {
        // removes timestamps of the form YYYY-MM-DD <SOMEID:[somedigits]>
        return output.replaceAll(/\d\d\d\d.*?\d\d\d> /gim, '');
      });
      const resultCfgVal = await testRunner.runZweTest(cfgYaml, 'config validate');
      expect(resultCfgVal.stdout).not.toBeNull();
      expect(resultCfgVal.cleanedStdout).toMatchSnapshot();
      expect(resultCfgVal.rc).toBe(0);

      const resultValCfg = await testRunner.runZweTest(cfgYaml, 'validate config');
      expect(resultValCfg.stdout).not.toBeNull();
      expect(resultValCfg.cleanedStdout).toMatchSnapshot();
      expect(resultValCfg.rc).toBe(0);

      expect(resultCfgVal.cleanedStdout).toEqual(resultValCfg.cleanedStdout);
    });
  });
});
