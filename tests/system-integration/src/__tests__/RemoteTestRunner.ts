/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { Session } from '@zowe/imperative';
import { getZosmfSession } from '../zowe';
import * as uss from '../uss';
import ZoweYamlType from '../ZoweYamlType';
import { REMOTE_TEST_DIR, TEST_YAML_DIR } from '../constants';
import * as files from '@zowe/zos-files-for-zowe-sdk';
import * as fs from 'fs-extra';
import * as YAML from 'yaml';
import { log } from 'console';

export class RemoteTestRunner {
  private session: Session;

  RemoteTestRunner() {
    log('init');
    this.session = getZosmfSession();
  }

  public async runRaw(command: string, cwd: string = REMOTE_TEST_DIR): Promise<TestOutput> {
    this.session = getZosmfSession();
    const output = await uss.runCommand(`${command}`, cwd);
    return {
      stdout: output.data,
      rc: output.rc,
    };
  }

  /**
   *
   * @param zoweYaml
   * @param zweCommand
   * @param cwd
   */
  public async runTest(zoweYaml: ZoweYamlType, zweCommand: string, cwd: string = REMOTE_TEST_DIR): Promise<TestOutput> {
    console.log(this.session);
    this.session = getZosmfSession();
    console.log(this.session);
    let command = zweCommand.trim();
    if (command.startsWith('zwe')) {
      command = command.replace(/zwe/, '');
    }
    const testName = expect.getState().currentTestName;
    const stringZoweYaml = YAML.stringify(zoweYaml);
    fs.writeFileSync(`${TEST_YAML_DIR}/zowe.yaml.${testName}`, stringZoweYaml);
    await files.Upload.bufferToUssFile(this.session, `${REMOTE_TEST_DIR}/zowe.test.yaml`, Buffer.from(stringZoweYaml), {
      binary: false,
    });

    const output = await uss.runCommand(`./bin/zwe ${command} --config  ${REMOTE_TEST_DIR}/zowe.test.yaml`, cwd);
    return {
      stdout: output.data,
      rc: output.rc,
    };
  }
}

export type TestOutput = {
  stdout: string;
  rc: number;
};
