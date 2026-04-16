/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { REMOTE_SYSTEM_INFO } from '../../config/TestConfig';
import { RemoteTestRunner } from '../../zos/RemoteTestRunner';
import * as path from 'path';
import { uploadFileToUss } from '../../zos/Files';
import { FileType, TestFileActions } from '../../zos/TestFileActions';

const FAKE_NODE_PATH: string = path.resolve(REMOTE_SYSTEM_INFO.ussTestDir, '.fake_node');
const FAKE_JAVA_PATH: string = path.resolve(REMOTE_SYSTEM_INFO.ussTestDir, '.fake_java');
const RESOURCE_DIR = path.resolve('src', '__tests__', 'common', '__resources__');

export async function setupFakeJava(testRunner: RemoteTestRunner): Promise<string> {
  await testRunner.runRaw(`mkdir -p ${FAKE_JAVA_PATH}/bin`);
  await uploadFileToUss(path.resolve(RESOURCE_DIR, 'fakejava'), path.resolve(FAKE_JAVA_PATH, 'bin', 'java'), {
    binary: false,
  });
  await testRunner.runRaw(`chmod 755 ${path.resolve(FAKE_JAVA_PATH, 'bin', 'java')}`);
  return FAKE_JAVA_PATH;
}

export async function cleanupFakeJava(): Promise<void> {
  await TestFileActions.deleteAll([{ name: FAKE_JAVA_PATH, type: FileType.USS_FILE }]);
}

export async function cleanupFakeNode(): Promise<void> {
  await TestFileActions.deleteAll([{ name: FAKE_NODE_PATH, type: FileType.USS_FILE }]);
}

export async function setupFakeNode(testRunner: RemoteTestRunner): Promise<string> {
  await testRunner.runRaw(`mkdir -p ${FAKE_NODE_PATH}/bin`);
  await uploadFileToUss(path.resolve(RESOURCE_DIR, 'fakenode'), path.resolve(FAKE_NODE_PATH, 'bin', 'node'), {
    binary: false,
  });
  await testRunner.runRaw(`chmod 755 ${path.resolve(FAKE_NODE_PATH, 'bin', 'node')}`);
  return FAKE_NODE_PATH;
}
