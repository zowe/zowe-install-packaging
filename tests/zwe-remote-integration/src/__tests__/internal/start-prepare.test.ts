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
import { FileType, TestFile, TestFileActions } from '../../zos/TestFileActions';
import { REMOTE_SYSTEM_INFO } from '../../config/TestConfig';
import * as _ from 'lodash';
import { cleanupFakeJava, cleanupFakeNode, setupFakeJava, setupFakeNode } from '../common/common';

const testSuiteName = 'start-prepare-tests';
describe(`${testSuiteName}`, () => {
  let testRunner: RemoteTestRunner;
  let cfgYaml: ZoweYamlType;
  let defaultCfgYaml: ZoweYamlType;
  let workspaceEnv: TestFile;
  let FAKE_NODE_PATH: string;
  let FAKE_JAVA_PATH: string;
  const CONTROLLED_NODE_VERSION_ENV: string = 'NODE_TESTENV_VERSION';
  const CONTROLLED_JAVA_VERSION_ENV: string = 'JAVA_TESTENV_VERSION';

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
    defaultCfgYaml = ZoweConfig.getDefaultsYaml();
    workspaceEnv = {
      name: `${cfgYaml.zowe.workspaceDirectory}/.env`,
      type: FileType.USS_DIR,
    };
    const cleanSecurityManager = (input: string) => {
      return input.replaceAll(/TSS|ACF2|RACF/gi, 'ESMT'); // ESM TEST
    };
    testRunner.addCleanFn(cleanSecurityManager);
    FAKE_NODE_PATH = await setupFakeNode(testRunner);
    FAKE_JAVA_PATH = await setupFakeJava(testRunner);
  });
  beforeEach(async () => {
    cfgYaml = ZoweConfig.getZoweYaml();
    _.set(cfgYaml, 'zowe.launchScript.startupChecks.user', 'disabled');
    _.set(cfgYaml, 'zowe.launchScript.startupChecks.certificate', 'disabled');
    for (const component of Object.values(cfgYaml.components)) {
      if (component.port) {
        component.port = (Number(component.port) + 15000) % 65535;
      }
    }
    _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
    defaultCfgYaml = ZoweConfig.getDefaultsYaml();
    await testRunner.removeUssFileOrDirForTest('components/zss/bin/validate.sh'); // validate script causes rc=1
    await TestFileActions.deleteAll([workspaceEnv]);
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFileActions.deleteAll([workspaceEnv]);
    defaultCfgYaml = ZoweConfig.getDefaultsYaml();
    // always reset defaults yaml
    await testRunner.uploadDefaultsYaml(defaultCfgYaml, undefined, true);
  });

  afterAll(async () => {
    testRunner.shutdown();
    await cleanupFakeNode();
    await cleanupFakeJava();
  });

  describe('(SHORT)', () => {
    it('test startup user if uid=0', async () => {
      const uid = await testRunner.runRaw('id -u');
      // only run test if we're uid 0
      if (Number(uid) === 0) {
        _.set(cfgYaml, 'zowe.launchScript.startupChecks.user', 'exit');
        const result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
        expect(result.cleanedStdout.includes('Running as UID 0. Such a setting is strongly discouraged'));
      } else {
        expect(1).toBe(1);
      }
    });

    it('various combinations of settings impacting z/osmf scheme', async () => {
      // All combinations relevant fields are 3^6 or 3^7, too many to test in integration. Cover more common subset.
      /* eslint-disable max-len */
      // prettier-ignore
      const testCases = [
        // envs override expected result
        { 'aml.enabled': true, 'gw.enabled': false, 'zaas.client.attls': false, 'net.client.attls': false, 'net.server.attls': false, 'cmd.env': { ZOSMF_SCHEME: 'http' }, 'result': 'http' },
        { 'aml.enabled': true, 'gw.enabled': false, 'zaas.client.attls': true, 'net.client.attls': false, 'net.server.attls': false, 'cmd.env': { ZWE_zOSMF_scheme: 'https' }, 'result': 'https' },
        { 'aml.enabled': true, 'gw.enabled': false, 'zaas.client.attls': false, 'net.client.attls': false, 'net.server.attls': false, 'cmd.env': { ZOSMF_SCHEME: 'http', ZWE_zOSMF_scheme: 'https' }, 'result': 'http' },
        // no envs override rest. nulls are "no value"
        { 'aml.enabled': true, 'gw.enabled': true, 'zaas.client.attls': false, 'net.client.attls': false, 'net.server.attls': false, 'cmd.env': {}, 'result': 'https' },
        { 'aml.enabled': true, 'gw.enabled': true, 'zaas.client.attls': false, 'net.client.attls': false, 'net.server.attls': false, 'cmd.env': {}, 'result': 'https' },
        { 'aml.enabled': true, 'gw.enabled': true, 'zaas.client.attls': true, 'net.client.attls': false, 'net.server.attls': false, 'cmd.env': {}, 'result': 'http' },
        { 'aml.enabled': false, 'gw.enabled': true, 'zaas.client.attls': false, 'net.client.attls': false, 'net.server.attls': true, 'cmd.env': {}, 'result': 'https' },
        { 'aml.enabled': false, 'gw.enabled': true, 'zaas.client.attls': true, 'net.client.attls': false, 'net.server.attls': false, 'cmd.env': {}, 'result': 'http' },
        { 'aml.enabled': true, 'gw.enabled': false, 'zaas.client.attls': false, 'net.client.attls': true, 'net.server.attls': false, 'cmd.env': {}, 'result': 'http' },
        { 'aml.enabled': true, 'gw.enabled': false, 'zaas.client.attls': false, 'net.client.attls': false, 'net.server.attls': true, 'cmd.env': {}, 'result': 'https' },
        { 'aml.enabled': true, 'gw.enabled': false, 'zaas.client.attls': null, 'net.client.attls': null, 'net.server.attls': true, 'cmd.env': {}, 'result': 'http' },
        { 'aml.enabled': true, 'gw.enabled': false, 'zaas.client.attls': null, 'net.client.attls': null, 'net.server.attls': null, 'cmd.env': {}, 'result': 'https' },
        { 'aml.enabled': false, 'gw.enabled': true, 'zaas.client.attls': null, 'net.client.attls': false, 'net.server.attls': false, 'cmd.env': {}, 'result': 'https' },
        { 'aml.enabled': false, 'gw.enabled': true, 'zaas.client.attls': true, 'net.client.attls': null, 'net.server.attls': false, 'cmd.env': {}, 'result': 'http' },
        { 'aml.enabled': false, 'gw.enabled': true, 'zaas.client.attls': false, 'net.client.attls': true, 'net.server.attls': null, 'cmd.env': {}, 'result': 'http' },
        { 'aml.enabled': false, 'gw.enabled': true, 'zaas.client.attls': null, 'net.client.attls': null, 'net.server.attls': false, 'cmd.env': {}, 'result': 'https' },
      ];

      /* eslint-enable max-len */
      for (const test of testCases) {
        cfgYaml = ZoweConfig.getZoweYaml(); // reset every test
        delete cfgYaml.zowe.network.server.tls;
        _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
        _.set(cfgYaml, 'zowe.launchScript.startupChecks.zosmf', 'exit');
        _.set(cfgYaml, 'zowe.launchScript.startupChecks.user', 'disabled');
        _.set(cfgYaml, 'zowe.launchScript.startupChecks.certificate', 'disabled');
        cfgYaml.zOSMF.port = Number(cfgYaml.zOSMF.port) + 1; // intentionally bad port: quit early and print z/osmf URL

        _.set(cfgYaml, 'components.apiml.enabled', test['aml.enabled']);
        _.set(cfgYaml, 'components.zaas.zowe.network.client.tls.attls', test['zaas.client.attls']);
        _.set(cfgYaml, 'components.gateway.enabled', test['gw.enabled']);
        _.set(cfgYaml, 'zowe.network.server.tls.attls', test['net.server.attls']);
        _.set(cfgYaml, 'zowe.network.client.tls.attls', test['net.client.attls']);
        _.set(cfgYaml, 'zowe.environments', test['cmd.env']);
        const result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
        const verifyResult = new RegExp(`Could not validate if z/OSMF is available on.*${test['result']}://.*?$`, 'gm');
        expect(verifyResult.exec(result.cleanedStdout)).not.toBeNull();
      }
    });

    it('z/OSMF with mode: exit', async () => {
      _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
      _.set(cfgYaml, 'zowe.launchScript.startupChecks.zosmf', 'exit');
      let result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.stdout).not.toBeNull();
      expect(result.stdout.includes('Successfully checked z/OSMF is available')).toBe(true);

      cfgYaml.zOSMF.port = Number(cfgYaml.zOSMF.port) + 1; // bad port
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.stdout).not.toBeNull();
      expect(result.stdout.includes('Could not validate if z/OSMF is available on')).toBe(true);
      expect(result.stdout.includes('Zosmf validation failed')).toBe(true);
    });

    // with warn mode, global validations should succeed when z/osmf check fails
    it('z/OSMF with mode: warn', async () => {
      _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
      _.set(cfgYaml, 'zowe.launchScript.startupChecks.zosmf', 'warn');
      let result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.stdout).not.toBeNull();
      expect(result.stdout.includes('Successfully checked z/OSMF is available')).toBe(true);

      cfgYaml.zOSMF.port = Number(cfgYaml.zOSMF.port) + 1; // bad port
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.stdout).not.toBeNull();
      expect(result.stdout.includes('Could not validate if z/OSMF is available on')).toBe(true);
      expect(result.stdout.includes('global validations are successful')).toBe(true);
    });

    // test when disabled, there's no messages about z/osmf and global validations pass
    it('z/OSMF with mode: disabled', async () => {
      _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
      _.set(cfgYaml, 'zowe.launchScript.startupChecks.zosmf', 'disabled');
      let result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.stdout).not.toBeNull();
      expect(result.stdout.includes('Successfully checked z/OSMF is available')).toBe(false);
      expect(result.stdout.includes('Could not validate if z/OSMF is available on')).toBe(false);
      expect(result.stdout.includes('global validations are successful')).toBe(true);

      cfgYaml.zOSMF.port = Number(cfgYaml.zOSMF.port) + 1; // bad port
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.stdout).not.toBeNull();
      expect(result.stdout.includes('Successfully checked z/OSMF is available')).toBe(false);
      expect(result.stdout.includes('Could not validate if z/OSMF is available on')).toBe(false);
      expect(result.stdout.includes('global validations are successful')).toBe(true);
    });

    it('modulith disabled', async () => {
      cfgYaml.components.apiml.enabled = false;
      const result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('default startupChecks behavior', async () => {
      cfgYaml.zowe.launchScript = ZoweConfig.getZoweYaml().zowe.launchScript; // reset launchScript to defaults
      _.set(cfgYaml, 'zowe.launchScript.startupChecks.user', 'disabled');
      _.set(cfgYaml, 'zowe.launchScript.startupChecks.certificate', 'disabled');
      let result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(67); // ZWEL0323E: Certificate validation failed. Fix errors listed before starting Zowe.

      _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
      _.set(cfgYaml, 'zowe.launchScript.startupChecks.certificate', 'warn'); // lets the command complete
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('set startupChecks disabled', async () => {
      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'disabled';
      const result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('set startupChecks warn', async () => {
      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'warn';
      const result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('test startupChecks warn with node and java', async () => {
      _.set(cfgYaml, 'node.home', FAKE_NODE_PATH);
      _.set(cfgYaml, 'java.home', FAKE_JAVA_PATH);
      _.set(cfgYaml, 'zowe.launchScript.startupChecks.javaMin', 'warn');
      let result = await testRunner.runZweTest(cfgYaml, 'internal start prepare', undefined, {
        [CONTROLLED_JAVA_VERSION_ENV]: '1.1.2',
      });
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
      _.set(cfgYaml, 'zowe.launchScript.startupChecks.javaMin', 'exit');
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare', undefined, {
        [CONTROLLED_JAVA_VERSION_ENV]: '1.1.2',
      });
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      _.set(cfgYaml, 'zowe.launchScript.startupChecks.nodeMin', 'warn');
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare', undefined, {
        [CONTROLLED_NODE_VERSION_ENV]: '1.1.2',
      });
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
      _.set(cfgYaml, 'zowe.launchScript.startupChecks.nodeMin', 'exit');
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare', undefined, {
        [CONTROLLED_NODE_VERSION_ENV]: '1.1.2',
      });
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      _.set(cfgYaml, 'zowe.launchScript.startupChecks.nodeMax', 'warn');
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare', undefined, {
        [CONTROLLED_NODE_VERSION_ENV]: '99.1.2',
      });
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
      _.set(cfgYaml, 'zowe.launchScript.startupChecks.nodeMax', 'exit');
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare', undefined, {
        [CONTROLLED_NODE_VERSION_ENV]: '99.1.2',
      });
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      _.set(cfgYaml, 'zowe.launchScript.startupChecks.javaMax', 'warn');
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare', undefined, {
        [CONTROLLED_JAVA_VERSION_ENV]: '99.1.2',
      });
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      _.set(cfgYaml, 'zowe.launchScript.startupChecks.javaMax', 'exit');
      result = await testRunner.runZweTest(cfgYaml, 'internal start prepare', undefined, {
        [CONTROLLED_JAVA_VERSION_ENV]: '99.1.2',
      });
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('test combinations of startup default and ports', async () => {
      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'warn';
      defaultCfgYaml.zowe.launchScript.startupChecks.ports = 'disabled';
      let result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'exit';
      defaultCfgYaml.zowe.launchScript.startupChecks.ports = 'disabled';
      result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);

      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'disabled';
      defaultCfgYaml.zowe.launchScript.startupChecks.ports = 'warn';
      result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
      defaultCfgYaml.zowe.launchScript.startupChecks.default = 'disabled';
      defaultCfgYaml.zowe.launchScript.startupChecks.ports = 'exit';
      result = await testRunner.runZweTestWithDefaults(cfgYaml, defaultCfgYaml, 'internal start prepare');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });
  });
});
