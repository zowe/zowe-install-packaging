/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { REMOTE_TEARDOWN, LINGERING_REMOTE_FILES_FILE, TEST_JOBS_RUN_FILE } from './config/TestConfig';
import * as fs from 'fs-extra';
import * as jobs from '@zowe/zos-jobs-for-zowe-sdk';
import { getZosmfSession } from './zos/zowe';
import { TestAwareFiles, TestManagedFile } from './zos/TestAwareFiles';
module.exports = async () => {
  if (!REMOTE_TEARDOWN) {
    return;
  }

  // await uss.runCommand(`rm -rf ${REMOTE_SYSTEM_INFO.ussTestDir}`);

  if (fs.existsSync(`${LINGERING_REMOTE_FILES_FILE}`)) {
    const dsList = fs
      .readFileSync(`${LINGERING_REMOTE_FILES_FILE}`, 'utf8')
      .split('\n')
      .filter((line) => line.trim().length > 0);
    const dsDeletes: TestManagedFile[] = dsList.map((dsEntry) => {
      const dsPieces = dsEntry.split(':');
      const enumVal = Number(dsPieces[1]);
      const ds: TestManagedFile = {
        name: dsPieces[0],
        type: enumVal,
      };
      return ds;
    });

    await TestAwareFiles.deleteAll(dsDeletes);
  }

  if (fs.existsSync(`${TEST_JOBS_RUN_FILE}`)) {
    const jobList = fs
      .readFileSync(`${TEST_JOBS_RUN_FILE}`, 'utf8')
      .split('\n')
      .filter((line) => line.trim().length > 0);
    for (const job of jobList) {
      const jobPieces = job.split(':');
      const jobName = jobPieces[0];
      const jobId = jobPieces[1];
      console.log('Purging ' + job);
      await jobs.DeleteJobs.deleteJob(getZosmfSession(), jobName, jobId);
    }
  }

  // fs.rmdirSync(TEST_YAML_DIR);
};
