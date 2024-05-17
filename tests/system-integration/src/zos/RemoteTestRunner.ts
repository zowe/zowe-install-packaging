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
import ZoweYamlType from '../types/ZoweYamlType';
import { REMOTE_TEST_DIR, TEST_JOBS_RUN_FILE, THIS_TEST_ROOT_DIR } from '../config/TestConfig';
import * as files from '@zowe/zos-files-for-zowe-sdk';
import * as fs from 'fs-extra';
import * as YAML from 'yaml';
import * as jobs from '@zowe/zos-jobs-for-zowe-sdk';
export class RemoteTestRunner {
  private readonly yamlOutputDir: string;
  private readonly spoolOutputDir: string;
  private readonly session: Session;
  private trackedJobs: jobs.IDownloadAllSpoolContentParms[] = [];

  constructor(testGroup: string) {
    this.session = getZosmfSession();
    this.yamlOutputDir = `${THIS_TEST_ROOT_DIR}/.build/${testGroup}/yaml`;
    this.spoolOutputDir = `${THIS_TEST_ROOT_DIR}/.build/${testGroup}/spool`;
    fs.rmSync(this.yamlOutputDir, { recursive: true, force: true });
    fs.rmSync(this.spoolOutputDir, { recursive: true, force: true });
    fs.mkdirpSync(this.yamlOutputDir);
    fs.mkdirpSync(this.spoolOutputDir);
  }

  public async runRaw(command: string, cwd: string = REMOTE_TEST_DIR): Promise<TestOutput> {
    const output = await uss.runCommand(`${command}`, cwd);
    // Any non-deterministic output should be cleaned up for test snapshots.
    const cleanedOutput = output.data.replace(/(JOB[0-9]{5})/gim, 'JOB00000');
    return {
      stdout: output.data,
      cleanedStdout: cleanedOutput,
      rc: output.rc,
    };
  }

  public async collectSpool() {
    const testName = expect.getState().currentTestName.replace(/\s/g, '_');
    for (const job of this.trackedJobs) {
      jobs.DownloadJobs.downloadAllSpoolContentCommon(getZosmfSession(), {
        ...job,
        outDir: this.spoolOutputDir,
        extension: '.' + testName.substring(0, 40), // arbitrarily chosen to keep things readable...
      });
    }
    this.trackedJobs = [];
  }

  /**
   *
   * @param zoweYaml
   * @param zweCommand
   * @param cwd
   */
  public async runZweTest(zoweYaml: ZoweYamlType, zweCommand: string, cwd: string = REMOTE_TEST_DIR): Promise<TestOutput> {
    let command = zweCommand.trim();
    if (command.startsWith('zwe')) {
      command = command.replace(/zwe/, '');
    }
    const testName = expect.getState().currentTestName.replace(/\s/g, '_').substring(0, 40);
    const stringZoweYaml = YAML.stringify(zoweYaml);

    fs.writeFileSync(`${this.yamlOutputDir}/zowe.yaml.${testName}`, stringZoweYaml);
    await files.Upload.fileToUssFile(
      this.session,
      `${this.yamlOutputDir}/zowe.yaml.${testName}`,
      `${REMOTE_TEST_DIR}/zowe.test.yaml`,
      {
        binary: false,
      },
    );

    const output = await uss.runCommand(`./bin/zwe ${command} --config  ${REMOTE_TEST_DIR}/zowe.test.yaml`, cwd);

    const matches = output.data.matchAll(/([A-Za-z0-9]{4,8})\((JOB[0-9]{1,5})\) completed with RC=(.*)$/gim);

    // for each match, 0=full matched string, 1=jobname, 2=jobid, 3=rc
    for (const match of matches) {
      fs.appendFileSync(TEST_JOBS_RUN_FILE, `${match[1]}:${match[2]}`);
      this.trackedJobs.push({
        jobname: match[1],
        jobid: match[2],
      });
    }

    // Any non-deterministic output should be cleaned up for test snapshots.
    const cleanedOutput = output.data.replace(/(JOB[0-9]{5})/gim, 'JOB00000');

    return {
      stdout: output.data,
      cleanedStdout: cleanedOutput,
      rc: output.rc,
    };
  }
}

export type TestOutput = {
  stdout: string;
  cleanedStdout: string;
  rc: number;
};
