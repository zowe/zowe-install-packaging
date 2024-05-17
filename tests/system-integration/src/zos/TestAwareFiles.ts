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
        try {
          deleteOps.push({ ds: dataset, action: files.Delete.vsam(this.session, dataset.name, { purge: true }) });
        } catch (error) {
          // TODO: ?
        }
      } else if (dataset.type === DatasetType.ZFS) {
        try {
          deleteOps.push({ ds: dataset, action: files.Delete.zfs(this.session, dataset.name, {}) });
        } catch (error) {
          // TODO: ?
        }
      } else if (dataset.type === DatasetType.NON_CLUSTER) {
        try {
          deleteOps.push({ ds: dataset, action: files.Delete.dataSet(this.session, dataset.name, {}) });
        } catch (error) {
          // TODO: ?
        }
      }
    });
    deleteOps.forEach(async (dsDelete) => {
      const res = await dsDelete.action;
      if (!res.success) {
        console.log(`Issue deleting ${dsDelete.ds.name}. Will try again during teardown.`);
        fs.appendFileSync(TEST_DATASETS_LINGERING_FILE, `${dsDelete.ds.name}:${dsDelete.ds.type}`);
      }
    });
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

export enum DatasetType {
  NON_CLUSTER,
  VSAM,
  ZFS,
}
