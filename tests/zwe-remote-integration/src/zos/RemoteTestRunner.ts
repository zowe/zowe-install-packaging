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
import { getSession } from './ZosmfSession';
import * as uss from './Uss';
import ZoweYamlType from '../config/ZoweYamlType';
import { REMOTE_SYSTEM_INFO, TEST_COLLECT_SPOOL, TEST_JOBS_RUN_FILE, TEST_OUTPUT_DIR } from '../config/TestConfig';
import * as files from '@zowe/zos-files-for-zowe-sdk';
import * as fs from 'fs-extra';
import * as YAML from 'yaml';
import * as jobs from '@zowe/zos-jobs-for-zowe-sdk';
import { basename } from 'path';

/**
 * RemoteTestRunner is a class which drives actions on the backend test environment and
 *   contains utility functions which are helpful in context of those tests. Utility
 *   functions include collecting relevant spool, removing backend files and later restoring them,
 *   and cleaning output returned from the test system so it contains no environment-specific
 *   references.
 */
export class RemoteTestRunner {
  private readonly REMOTE_TEST_TMP_DIR: string = `${REMOTE_SYSTEM_INFO.ussTestDir}/test_tmp`;
  private readonly yamlOutputTemplate: string;
  private readonly tmpDir: string;
  private readonly spoolOutputTemplate: string;
  private readonly session: Session;
  private trackedFiles: TrackedFile[] = [];
  private trackedJobs: jobs.IDownloadAllSpoolContentParms[] = [];
  private cleanFns: ((stdout: string) => string)[] = [];

  constructor(testGroup: string) {
    this.session = getSession();
    this.tmpDir = `${TEST_OUTPUT_DIR}/${testGroup}/tmp`;
    this.yamlOutputTemplate = `${TEST_OUTPUT_DIR}/${testGroup}/{{ testInstance }}/yaml`;
    this.spoolOutputTemplate = `${TEST_OUTPUT_DIR}/${testGroup}//{{ testInstance }}/spool`;
  }

  public async runRaw(command: string, cwd: string = REMOTE_SYSTEM_INFO.ussTestDir): Promise<TestOutput> {
    const output = await uss.runCommand(`${command}`, cwd);
    // Any non-deterministic output should be cleaned up for test snapshots.
    const cleanedOutput = this.cleanOutput(output.data);
    return {
      stdout: output.data,
      cleanedStdout: cleanedOutput,
      rc: output.rc,
    };
  }

  /**
   *  Collects spool, restores files tracked by #removeFileForTest, and cleans up local work dirs
   */
  public async postTest() {
    if (TEST_COLLECT_SPOOL) {
      await this.collectSpool();
    }
    await this.restoreFiles();
    fs.rmSync(this.tmpDir, { recursive: true, force: true });
  }

  public async readFile(
    filePath: string,
    isBinary: boolean = false,
    readContent: boolean = true,
    cwd: string = REMOTE_SYSTEM_INFO.ussTestDir,
  ): Promise<{ content: string; file: string }> {
    const tmpFile = `${this.tmpDir}/${expect.getState().currentTestName}/${basename(filePath)}`;
    await files.Download.ussFile(this.session, `${cwd}/${filePath}`, { file: tmpFile, binary: isBinary });
    let content;
    if (readContent) {
      content = fs.readFileSync(tmpFile).toString();
    }
    return {
      content: content,
      file: tmpFile,
    };
  }

  public async collectSpool() {
    const testName = expect.getState().currentTestName.replace(/\s/g, '_');
    const spoolOutputDir = this.spoolOutputTemplate.replace('{{ testInstance }}', testName);
    fs.mkdirpSync(spoolOutputDir);
    for (const job of this.trackedJobs) {
      await jobs.DownloadJobs.downloadAllSpoolContentCommon(getSession(), {
        ...job,
        outDir: spoolOutputDir,
        extension: '.txt', // arbitrarily chosen to keep things readable...
      });
    }
    this.trackedJobs = [];
  }

  public async restoreFiles() {
    for (const trackedFile of this.trackedFiles) {
      await this.runRaw(`mv ${trackedFile.tmpFile} ${trackedFile.srcFile}`);
    }
    this.trackedFiles = [];
  }

  public async removeFileForTest(filePath: string) {
    const flattenedTmpName = filePath.replaceAll('/', '_');
    await this.runRaw(`mkdir -p ${this.REMOTE_TEST_TMP_DIR}`);
    await this.runRaw(`mv ${filePath} ${this.REMOTE_TEST_TMP_DIR}/${flattenedTmpName}`);
    this.trackedFiles.push({
      srcFile: filePath,
      tmpFile: `${this.REMOTE_TEST_TMP_DIR}/${flattenedTmpName}`,
    });
  }

  public addCleanFn(replaceFn: (output: string) => string) {
    this.cleanFns.push(replaceFn);
  }

  private cleanOutput(stdout: string): string {
    let cleanedOutput = stdout;
    // user-supplied
    this.cleanFns.forEach((fn) => {
      cleanedOutput = fn(cleanedOutput);
    });
    // built-in
    return cleanedOutput
      .replace(/(JOB[0-9]{5})/gim, 'JOB00000')
      .replaceAll(`${REMOTE_SYSTEM_INFO.prefix}`, 'TEST.DATASET.PFX')
      .replaceAll(`${this.session.ISession.user}`, 'TESTUSR0')
      .replace(/\/tmp\/\.zweenv-[0-9]{3,5}/g, '/tmp/.zweenv-0000')
      .replaceAll(REMOTE_SYSTEM_INFO.volume, 'TSTVOL')
      .replaceAll(REMOTE_SYSTEM_INFO.zosJavaHome, '/test/java/home')
      .replaceAll(REMOTE_SYSTEM_INFO.zosNodeHome, '/test/node/home')
      .replaceAll(REMOTE_SYSTEM_INFO.hostname, 'some.test.hostname')
      .replaceAll(REMOTE_SYSTEM_INFO.zosmfPort, '12321')
      .replaceAll(REMOTE_SYSTEM_INFO.ussTestDir, '/test/dir');
  }

  public async runZweTestWithDefaults(zoweYaml: ZoweYamlType, defaultYaml: ZoweYamlType, cwd: string = REMOTE_SYSTEM_INFO.ussTestDir) {
    const testName = expect.getState().currentTestName.replace(/\s/g, '_').substring(0, 40);
    const stringDefaultYaml = YAML.stringify(defaultYaml);
    const yamlOutputDir = this.yamlOutputTemplate.replace('{{ testInstance }}', testName);
    await this.removeFileForTest('files/defaults.yaml');
    fs.writeFileSync(`${yamlOutputDir}/defaults.yaml.${testName}`, stringDefaultYaml);
    await files.Upload.fileToUssFile(
      this.session,
      `${yamlOutputDir}/defaults.yaml.${testName}`,
      `${REMOTE_SYSTEM_INFO.ussTestDir}/files/defaults.yaml`,
      {
        binary: false,
      },
    );
    await this.runZweTest(zoweYaml, cwd);
  }

  /**
   *
   * @param zoweYaml
   * @param zweCommand
   * @param cwd
   */
  public async runZweTest(
    zoweYaml: ZoweYamlType,
    zweCommand: string,
    cwd: string = REMOTE_SYSTEM_INFO.ussTestDir,
  ): Promise<TestOutput> {
    let command = zweCommand.trim();
    if (command.startsWith('zwe')) {
      command = command.replace(/zwe/, '');
    }
    const testName = expect.getState().currentTestName.replace(/\s/g, '_').substring(0, 40);
    const stringZoweYaml = YAML.stringify(zoweYaml);
    const yamlOutputDir = this.yamlOutputTemplate.replace('{{ testInstance }}', testName);
    fs.mkdirpSync(yamlOutputDir);

    fs.writeFileSync(`${yamlOutputDir}/zowe.yaml.${testName}`, stringZoweYaml);
    await files.Upload.fileToUssFile(
      this.session,
      `${yamlOutputDir}/zowe.yaml.${testName}`,
      `${REMOTE_SYSTEM_INFO.ussTestDir}/zowe.test.yaml`,
      {
        binary: false,
      },
    );

    const output = await uss.runCommand(`./bin/zwe ${command} --config  ${REMOTE_SYSTEM_INFO.ussTestDir}/zowe.test.yaml`, cwd);

    const matches = output.data.matchAll(/([A-Za-z0-9]{4,8})\((JOB[0-9]{1,5})\) completed with RC=(.*)$/gim);

    // for each match, 0=full matched string, 1=jobname, 2=jobid, 3=rc
    for (const match of matches) {
      fs.appendFileSync(TEST_JOBS_RUN_FILE, `${match[1]}:${match[2]}\n`);
      this.trackedJobs.push({
        jobname: match[1],
        jobid: match[2],
      });
    }

    // Any non-deterministic output should be cleaned up for test snapshots.
    const cleanedOutput = this.cleanOutput(output.data);

    return {
      stdout: output.data,
      cleanedStdout: cleanedOutput,
      rc: output.rc,
    };
  }
}

type TrackedFile = {
  srcFile: string;
  tmpFile: string;
};

export type TestOutput = {
  stdout: string;
  cleanedStdout: string;
  rc: number;
};
