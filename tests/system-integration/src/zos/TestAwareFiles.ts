/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as fs from 'fs-extra';
import { getZosmfSession } from '../zowe';
import * as files from '@zowe/zos-files-for-zowe-sdk';
import { TEST_DATASETS_LINGERING_FILE } from '../config/TestConfig';
export class TestAwareFiles {
  private static readonly session = getZosmfSession();

  constructor() {}

  public static async deleteAll(datasets: TestManagedDataset[]) {
    const deleteOps: DeleteDs[] = [];
    datasets.forEach((dataset) => {
      if (dataset.type === DatasetType.VSAM) {
        deleteOps.push({ ds: dataset, action: files.Delete.vsam(this.session, dataset.name, { purge: true }) });
      } else if (dataset.type === DatasetType.ZFS) {
        deleteOps.push({ ds: dataset, action: files.Delete.zfs(this.session, dataset.name, {}) });
      } else if (dataset.type === DatasetType.NON_CLUSTER) {
        deleteOps.push({ ds: dataset, action: files.Delete.dataSet(this.session, dataset.name, {}) });
      }
    });
    for (const dsDelete of deleteOps) {
      let res = { success: false };
      try {
        res = await dsDelete.action;
      } catch (error) {
        // if error message indicates 404, dataset didn't exist to be deleted.
        if (error?.mDetails?.msg && error.mDetails.msg.includes('status 404')) {
          res.success = true; // consider dataset deleted.
        }
      }
      if (!res.success) {
        console.log(`Issue deleting ${dsDelete.ds.name}. Will try again during teardown.`);
        fs.appendFileSync(TEST_DATASETS_LINGERING_FILE, `${dsDelete.ds.name}:${dsDelete.ds.type}\n`);
      }
    }
  }
}

type DeleteDs = {
  ds: TestManagedDataset;
  action: Promise<files.IDeleteVsamResponse | files.IZosFilesResponse>;
};

export type TestManagedDataset = {
  name: string;
  type: DatasetType;
};

// Not sure why eslint was flagging these?
export enum DatasetType {
  // eslint-disable-next-line no-unused-vars
  NON_CLUSTER,
  // eslint-disable-next-line no-unused-vars
  VSAM,
  // eslint-disable-next-line no-unused-vars
  ZFS,
}
