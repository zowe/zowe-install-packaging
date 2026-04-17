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
import { REMOTE_SYSTEM_INFO } from '../../config/TestConfig';
import { cleanupFakeJava, cleanupFakeNode, setupFakeJava, setupFakeNode } from '../common/common';

const testSuiteName = 'zwe-validate-dependencies';
describe(`${testSuiteName}`, () => {
  let cfgYaml: ZoweYamlType;
  let testRunner: RemoteTestRunner;
  let cleanupFiles: TestFile[] = []; // a list of datasets deleted after every test
  let FAKE_NODE_PATH: string;
  let FAKE_JAVA_PATH: string;
  const CONTROLLED_NODE_VERSION_ENV: string = 'NODE_TESTENV_VERSION';
  const CONTROLLED_JAVA_VERSION_ENV: string = 'JAVA_TESTENV_VERSION';

  beforeAll(async () => {
    testRunner = new RemoteTestRunner(testSuiteName);
    cfgYaml = ZoweConfig.getZoweYaml();
    FAKE_NODE_PATH = await setupFakeNode(testRunner);
    FAKE_JAVA_PATH = await setupFakeJava(testRunner);
  });
  beforeEach(async () => {
    cfgYaml = ZoweConfig.getZoweYaml();
    _.set(cfgYaml, 'components.apiml.enabled', true);
    // upload the resources to a directory in the test runner's workspace
  });

  afterEach(async () => {
    await testRunner.postTest();
    await TestFileActions.deleteAll(cleanupFiles);
    cleanupFiles = [];
  });

  afterAll(async () => {
    // always upload defaults to protect against failing tests creating a dirty workspace
    await testRunner.uploadDefaultsYaml(ZoweConfig.getDefaultsYaml(), undefined, true);
    testRunner.shutdown();
    await cleanupFakeNode();
    await cleanupFakeJava();
  });

  describe('(SHORT)', () => {
    it('validate dependencies', async () => {
      _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome); // pass both node and java
      const result = await testRunner.runZweTest(cfgYaml, 'validate dependencies');
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(0);
    });

    it('fail to validate one dependency - min version too low', async () => {
      _.set(cfgYaml, 'node.home', FAKE_NODE_PATH);
      let result = await testRunner.runZweTest(cfgYaml, `validate dependencies`, undefined, {
        [CONTROLLED_NODE_VERSION_ENV]: '1.1.2',
      }); // java good, node bad
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(121); // this fails during requireNode(), dropping w/RC=121 instead of returning to validate script

      _.set(cfgYaml, 'java.home', FAKE_JAVA_PATH);
      _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
      result = await testRunner.runZweTest(cfgYaml, 'validate dependencies', undefined, {
        [CONTROLLED_JAVA_VERSION_ENV]: '1.1.2',
      }); // node good, java bad
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    it('fail to validate one dependency - max version too high', async () => {
      _.set(cfgYaml, 'node.home', FAKE_NODE_PATH);
      let result = await testRunner.runZweTest(cfgYaml, `validate dependencies`, undefined, {
        [CONTROLLED_NODE_VERSION_ENV]: '999.1.2',
      }); // java good, node bad
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);

      _.set(cfgYaml, 'java.home', FAKE_JAVA_PATH);
      _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
      result = await testRunner.runZweTest(cfgYaml, 'validate dependencies', undefined, {
        [CONTROLLED_JAVA_VERSION_ENV]: '999.1.2',
      }); // node good, java bad
      expect(result.cleanedStdout).toMatchSnapshot();
      expect(result.rc).toBe(1);
    });

    describe('_(NODE)', () => {
      beforeEach(async () => {
        _.set(cfgYaml, 'node.home', REMOTE_SYSTEM_INFO.zosNodeHome);
      });

      it('validate node version without app-server', async () => {
        _.set(cfgYaml, 'components.app-server.enabled', false);
        const result = await testRunner.runZweTest(cfgYaml, 'validate dependencies node');
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);
      });

      it('validate node version with app-server', async () => {
        _.set(cfgYaml, 'components.app-server.enabled', true);
        const result = await testRunner.runZweTest(cfgYaml, 'validate dependencies node');
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);
      });

      it('fail to validate node dependency', async () => {
        _.set(cfgYaml, 'node.home', '/invalid/path');
        let result = await testRunner.runZweTest(cfgYaml, 'validate dependencies node');
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(121);

        delete cfgYaml.node.home;
        result = await testRunner.runZweTest(cfgYaml, 'validate dependencies node');
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(121);

        _.set(cfgYaml, 'node.home', FAKE_NODE_PATH);
        result = await testRunner.runZweTest(cfgYaml, 'validate dependencies node', undefined, {
          [CONTROLLED_NODE_VERSION_ENV]: '1.1.2',
        });
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(121);

        result = await testRunner.runZweTest(cfgYaml, 'validate dependencies node', undefined, {
          [CONTROLLED_NODE_VERSION_ENV]: '99.1.2',
        });
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(1);
      });
    });

    describe('_(JAVA)', () => {
      it('validate java version without apiml', async () => {
        _.set(cfgYaml, 'components.apiml.enabled', false);
        _.set(cfgYaml, 'components.gateway.enabled', false);
        _.set(cfgYaml, 'components.discovery.enabled', false);
        _.set(cfgYaml, 'components.zaas.enabled', false);
        _.set(cfgYaml, 'components.api-catalog.enabled', false);
        _.set(cfgYaml, 'components.caching-service.enabled', false);
        const result = await testRunner.runZweTest(cfgYaml, 'validate dependencies java');
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);
      });

      it('validate java version with apiml', async () => {
        _.set(cfgYaml, 'components.apiml.enabled', true);
        _.set(cfgYaml, 'components.gateway.enabled', true);
        _.set(cfgYaml, 'components.discovery.enabled', true);
        _.set(cfgYaml, 'components.zaas.enabled', true);
        _.set(cfgYaml, 'components.api-catalog.enabled', true);
        _.set(cfgYaml, 'components.caching-service.enabled', true);
        const result = await testRunner.runZweTest(cfgYaml, 'validate dependencies java');
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(0);
      });

      it('fail to validate java dependency', async () => {
        _.set(cfgYaml, 'java.home', '/invalid/path');
        let result = await testRunner.runZweTest(cfgYaml, 'validate dependencies java');
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(1);

        _.set(cfgYaml, 'java.home', FAKE_JAVA_PATH);
        result = await testRunner.runZweTest(cfgYaml, 'validate dependencies java', undefined, {
          [CONTROLLED_JAVA_VERSION_ENV]: '1.1.2',
        });
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(1);

        result = await testRunner.runZweTest(cfgYaml, 'validate dependencies java', undefined, {
          [CONTROLLED_JAVA_VERSION_ENV]: '99.1.2',
        });
        expect(result.cleanedStdout).toMatchSnapshot();
        expect(result.rc).toBe(1);
      });
    });
  });
});
