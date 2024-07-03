/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { REMOTE_SYSTEM_INFO } from '../config/TestConfig';
import * as files from '@zowe/zos-files-for-zowe-sdk';
import { getSession } from './ZosmfSession';
import _ from 'lodash';

export async function createPds(pdsName: string, createOpts: Partial<files.ICreateDataSetOptions>) {
  const defaultPdsOpts: files.ICreateDataSetOptions = {
    lrecl: 80,
    recfm: 'FB',
    blksize: 32720,
    alcunit: 'cyl',
    primary: 10,
    secondary: 2,
    dsorg: 'PO',
    dsntype: 'library',
    volser: REMOTE_SYSTEM_INFO.volume,
  };
  const mergedOpts: Partial<files.ICreateDataSetOptions> = _.merge({}, defaultPdsOpts, createOpts);
  console.log(`Creating ${pdsName}`);
  await createDataset(pdsName, files.CreateDataSetTypeEnum.DATA_SET_PARTITIONED, mergedOpts);
}

export async function createDataset(
  dsName: string,
  type: files.CreateDataSetTypeEnum,
  createOpts: Partial<files.ICreateDataSetOptions>,
) {
  console.log(`Checking if ${dsName} exists...`);
  const listPdsResp = await files.List.dataSet(getSession(), dsName, {
    pattern: dsName,
  });
  console.log(JSON.stringify(listPdsResp));
  const respItems: { [key: string]: string }[] = listPdsResp.apiResponse?.items;
  if (respItems?.find((item) => item.dsname === dsName) != null) {
    console.log(`Pds exists, cleaning up...`);
    await files.Delete.dataSet(getSession(), dsName, {});
  }
  console.log(`Creating ${dsName}`);
  await files.Create.dataSet(getSession(), type, dsName, createOpts);
}
