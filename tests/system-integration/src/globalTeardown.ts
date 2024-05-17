/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { REMOTE_TEARDOWN, REMOTE_TEST_DIR, TEST_JOBS_RUN_FILE as TEST_JOBS_TRACKING_FILE } from './config/TestConfig';
import * as uss from './uss';
import * as fs from 'fs-extra';
import * as jobs from '@zowe/zos-jobs-for-zowe-sdk';
import { getZosmfSession } from './zowe';
module.exports = async () => {
  if (!REMOTE_TEARDOWN) {
    return;
  }

  await uss.runCommand(`rm -rf ${REMOTE_TEST_DIR}`);

  // await files.Dataset.deleteDataset();

  if (fs.existsSync(`${TEST_JOBS_TRACKING_FILE}`)) {
    fs.readFileSync(`${TEST_JOBS_TRACKING_FILE}`, 'utf8')
      .split('\n')
      .forEach(async (job) => {
        const jobPieces = job.split(':');
        const jobName = jobPieces[0];
        const jobId = jobPieces[1];
        console.log('Purging ' + job);
        await jobs.DeleteJobs.deleteJob(getZosmfSession(), jobName, jobId);
        //
      });
  }

  // fs.rmdirSync(TEST_YAML_DIR);
};
