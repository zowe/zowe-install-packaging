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
import { getZosmfSession } from './zowe';
import * as files from '@zowe/zos-files-for-zowe-sdk';
import { LINGERING_REMOTE_FILES_FILE } from '../config/TestConfig';
export class TestFileActions {
  private static readonly session = getZosmfSession();

  constructor() {}

  public static async deleteAll(datasets: TestFile[]) {
    const deleteOps: DeleteFile[] = [];
    datasets.forEach((testFile) => {
      let delPromise;
      switch (testFile.type) {
        case FileType.DS_VSAM:
          delPromise = files.Delete.vsam(this.session, testFile.name, { purge: true });
          break;
        case FileType.DS_ZFS:
          delPromise = files.Delete.zfs(this.session, testFile.name, {});
          break;
        case FileType.DS_NON_CLUSTER:
          delPromise = files.Delete.dataSet(this.session, testFile.name, {});
          break;
        case FileType.USS_FILE:
          delPromise = files.Delete.ussFile(this.session, testFile.name, false);
          break;
        case FileType.USS_DIR:
          delPromise = files.Delete.ussFile(this.session, testFile.name, true);
          break;
      }
      deleteOps.push({ file: testFile, action: delPromise });
    });
    for (const dsDelete of deleteOps) {
      let res = { success: false };
      try {
        res = await dsDelete.action;
      } catch (error) {
        // if error message indicates 404, file didn't exist to be deleted.
        if (error?.mDetails?.msg && error.mDetails.msg.includes('status 404')) {
          res.success = true; // consider file deleted.
        }
      }
      if (!res.success) {
        console.log(`Issue deleting ${dsDelete.file.name}. Will try again during teardown.`);
        fs.appendFileSync(LINGERING_REMOTE_FILES_FILE, `${dsDelete.file.name}:${dsDelete.file.type}\n`);
      }
    }
  }
}

type DeleteFile = {
  file: TestFile;
  action: Promise<files.IDeleteVsamResponse | files.IZosFilesResponse>;
};

export type TestFile = {
  name: string;
  type: FileType;
};

// why is eslint flagging these?
export enum FileType {
  // eslint-disable-next-line no-unused-vars
  DS_NON_CLUSTER,
  // eslint-disable-next-line no-unused-vars
  DS_VSAM,
  // eslint-disable-next-line no-unused-vars
  DS_ZFS,
  // eslint-disable-next-line no-unused-vars
  USS_FILE,
  // eslint-disable-next-line no-unused-vars
  USS_DIR,
}
