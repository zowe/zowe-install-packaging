/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { CLEANUP_AFTER_TESTS, REMOTE_TEST_DIR, TEST_JOBS_RUN_FILE, TEST_YAML_DIR } from './constants';
import * as uss from './uss';
import * as fs from 'fs-extra';

module.exports = async () => {
  if (!CLEANUP_AFTER_TESTS) {
    return;
  }

  await uss.runCommand(`rm -rf ${REMOTE_TEST_DIR}`);

  if (fs.existsSync(`${TEST_JOBS_RUN_FILE}`)) {
    fs.readFileSync(`${TEST_JOBS_RUN_FILE}`, 'utf8')
      .split('\n')
      .forEach((job) => {
        //
        console.log('Purge ' + job);
      });
  }

  fs.rmdirSync(TEST_YAML_DIR);
};
