/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as uss from './uss';
import * as files from '@zowe/zos-files-for-zowe-sdk';
import { REMOTE_TEST_DIR, REPO_ROOT_DIR, TEST_YAML_DIR, THIS_TEST_BASE_YAML, THIS_TEST_ROOT_DIR } from './constants';
import * as fs from 'fs-extra';
import { getZosmfSession } from './zowe';

module.exports = async () => {
  // check directories and configmgr look OK
  console.log(`${REPO_ROOT_DIR}`);
  if (!fs.existsSync(`${REPO_ROOT_DIR}/bin/zwe`)) {
    throw new Error('Could not locate the zwe tool locally. Ensure you are running tests from the test project root');
  }
  const configmgrPax = fs.readdirSync(`${THIS_TEST_ROOT_DIR}/.build`).find((item) => /configmgr.*\.pax/g.test(item));
  if (configmgrPax == null) {
    throw new Error('Could not locate a configmgr pax in the .build directory');
  }

  console.log(`Using example-zowe.yaml as base for future zowe.yaml modifications...`);
  fs.copyFileSync(`${REPO_ROOT_DIR}/example-zowe.yaml`, THIS_TEST_BASE_YAML);
  fs.mkdirpSync(`${THIS_TEST_ROOT_DIR}/.build/zowe`);
  fs.mkdirpSync(`${TEST_YAML_DIR}`);
  console.log('Setting up remote server...');
  await uss.runCommand(`mkdir -p ${REMOTE_TEST_DIR}`);

  console.log(`Uploading ${configmgrPax} to ${REMOTE_TEST_DIR}/configmgr.pax ...`);
  await files.Upload.fileToUssFile(
    getZosmfSession(),
    `${THIS_TEST_ROOT_DIR}/.build/${configmgrPax}`,
    `${REMOTE_TEST_DIR}/configmgr.pax`,
    { binary: true },
  );

  console.log(`Uploading ${REPO_ROOT_DIR}/bin to ${REMOTE_TEST_DIR}/bin...`);
  await files.Upload.dirToUSSDirRecursive(getZosmfSession(), `${REPO_ROOT_DIR}/bin`, `${REMOTE_TEST_DIR}/bin/`, {
    binary: false,
    includeHidden: true,
  });

  console.log(`Unpacking configmgr and placing it in bin/utils ...`);
  await uss.runCommand(`pax -ppx -rf configmgr.pax && mv configmgr bin/utils/`, `${REMOTE_TEST_DIR}`);

  console.log('Remote server setup complete');
};
