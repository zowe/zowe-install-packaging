/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as _ from 'lodash';
import * as minimatch from 'minimatch';
import escapeStringRegexp from 'escape-string-regexp';
import { Session } from '@zowe/imperative';
import { getSession } from './ZosmfSession';
import { UssSession } from './UssSession';
import ZoweYamlType from '../config/ZoweYamlType';
import { REMOTE_SYSTEM_INFO, TEST_COLLECT_SPOOL, TEST_JOBS_RUN_FILE, TEST_OUTPUT_DIR } from '../config/TestConfig';
import * as files from '@zowe/zos-files-for-zowe-sdk';
import * as fs from 'fs-extra';
import * as YAML from 'yaml';
import * as jobs from '@zowe/zos-jobs-for-zowe-sdk';
import path, { basename } from 'path';
import { FileType } from './TestFileActions';

/**
 * RemoteTestRunner is a class which drives actions on the backend test environment and
 *   contains utility functions which are helpful in context of those tests.
 *
 *  Most commonly called method are:
 *  - runZweTest
 *  - runZweTestWithDefaults
 *  - postTest
 */
export class RemoteTestRunner {
  private readonly REMOTE_TEST_TMP_DIR: string = `${REMOTE_SYSTEM_INFO.ussTestDir}/.test_tmp`;
  private readonly yamlOutputTemplate: string;
  private readonly tmpDir: string;
  private readonly spoolOutputTemplate: string;
  private readonly otherOutputTemplate: string;
  private readonly session: Session;
  private trackedFiles: TrackedFile[] = [];
  private trackedJobs: jobs.IDownloadAllSpoolContentParms[] = [];
  private readonly cleanFns: ((stdout: string) => string)[] = [];
  private readonly uss: UssSession;
  private totalRuns: number = 0;
  private totalRuntime: number = 0;
  private maxRuntime: number = -1;
  private readonly dummyHostname: string = 'some.test.hostname';
  private readonly dummyPort: string = '12321';

  constructor(testGroup: string) {
    this.session = getSession();
    this.uss = UssSession.sharedSession();
    this.tmpDir = `${TEST_OUTPUT_DIR}/${testGroup}/tmp`;
    const baseOutputDir = `${TEST_OUTPUT_DIR}/${testGroup}/{{ testInstance }}`;
    this.yamlOutputTemplate = `${baseOutputDir}/yaml`;
    this.spoolOutputTemplate = `${baseOutputDir}/spool`;
    this.otherOutputTemplate = `${baseOutputDir}/other`;
    this.getSysName();
  }

  private async getSysName() {
    const sysname = await this.uss.runCommand('sysvar SYSNAME');
    REMOTE_SYSTEM_INFO.sensitiveDataToMask.push({ key: sysname.stdout.trim(), type: 'sysname' });
  }

  public shutdown() {
    console.log(`Total time spent in uss commands: ${this.totalRuntime / 1000} seconds`);
    console.log(`Max time spent in a single uss command: ${this.maxRuntime / 1000} seconds`);
    console.log(`Avg time spent per uss command: ${this.totalRuntime / this.totalRuns / 1000} seconds`);
    this.cleanFns.length = 0; // reset cleanFns
    this.uss.shutdown();
  }

  public async downloadMaskedUssFilesMatching(
    filePattern: string,
    remoteDir: string = REMOTE_SYSTEM_INFO.ussTestDir,
  ): Promise<string[]> {
    const normalizedRemote = remoteDir.endsWith('/') ? remoteDir.slice(0, -1) : remoteDir;
    const localMaskedFiles: string[] = [];
    const fileList = await files.List.fileList(this.session, `${normalizedRemote}`);

    if (fileList.apiResponse.items.length === 0) {
      console.log(`No files found in ${normalizedRemote}. API Response was ${fileList.success}.`);
      return localMaskedFiles;
    }
    const matchedFiles: string[] = minimatch.match(
      fileList.apiResponse.items.map((item: { name: string }) => item.name),
      filePattern,
      { dot: true },
    );
    for (const file of matchedFiles) {
      fs.mkdirpSync(this.tmpDir);
      const tmpFile = `${this.tmpDir}/${basename(file)}-${Date.now()}`;
      // const writeStream = fs.createWriteStream(tmpFile, { autoClose: true, mode: 0o775 });
      await files.Download.ussFile(this.session, `${normalizedRemote}/${file}`, {
        file: tmpFile,
      });
      const fileContents = fs.readFileSync(tmpFile).toString();
      const cleanedContents = this.cleanOutput(fileContents, []);
      fs.writeFileSync(tmpFile, cleanedContents);
      localMaskedFiles.push(path.resolve(tmpFile));
    }
    return localMaskedFiles;
  }

  public async runRaw(command: string, cwd: string = REMOTE_SYSTEM_INFO.ussTestDir): Promise<TestOutput> {
    const output = await this.uss.runCommand(`${command}`, cwd);
    // Any non-deterministic output should be cleaned up for test snapshots.
    const cleanedOutput = this.cleanOutput(output.consoleLog, []);
    return {
      stdout: output.consoleLog,
      cleanedStdout: cleanedOutput,
      rc: output.rc,
    };
  }

  /**
   * Collects a local file into the test output directory.
   * Use this to collect files that are not tracked by the test runner but useful to review.
   *
   * @param {string} filePath - The path of the file to copy.
   */
  public collectTestFile(filePath: string) {
    if (!fs.existsSync(filePath)) {
      console.log('warn: testrunner could not find the local file to collect: ' + filePath);
      return;
    }
    const testName = expect.getState().currentTestName.replace(/\s/g, '_');
    const outputDir = this.otherOutputTemplate.replace('{{ testInstance }}', testName);
    fs.mkdirpSync(outputDir);
    // cover cases where a single test saves multiple files with the same name
    let destFile = `${outputDir}/${basename(filePath)}`;
    let iter = 1;
    while (fs.existsSync(destFile) && iter < 100) {
      destFile = `${destFile}.${iter}`;
      iter++;
    }
    fs.copySync(filePath, destFile);
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
      switch (trackedFile.type) {
        case FileType.USS_FILE:
        case FileType.USS_DIR:
          await this.runRaw(`mv ${trackedFile.tmpFile} ${trackedFile.srcFile}`);
          break;
        case FileType.DS_NON_CLUSTER:
          try {
            await files.Delete.dataSet(this.session, trackedFile.srcFile, {});
          } catch (error: unknown) {
            // if we didn't find the dataset, it's safe to ignore the problem.
            // The test could've failed to create a dataset for example.
            if (!JSON.stringify(error).includes('status 404')) {
              throw error;
            }
          }
          if (trackedFile.tmpFile != null) {
            await files.Rename.dataSet(this.session, trackedFile.tmpFile, trackedFile.srcFile);
          }
          break;
        case FileType.DS_VSAM:
        case FileType.DS_ZFS:
          console.log(`Automation runner is trying to restore an unsupported file type. Details: ${JSON.stringify(trackedFile)}`);
          break;
      }
    }
    this.trackedFiles = [];
  }

  /**
   * Moves the datasets listed to a backup location.
   *
   * The datasets are restored with either the #postTest or #restore operations.
   */
  public async removeDatasetsForTest(datasets: string[]) {
    for (const dataset of datasets) {
      await this.removeDatasetForTest(dataset);
    }
  }

  /**
   * Moves a given dataset listed to a backup location.
   *
   * The dataset is restored with either the #postTest or #restore operations.
   */
  public async removeDatasetForTest(dataset: string) {
    try {
      const dsList = await files.List.dataSetsMatchingPattern(this.session, [dataset]);

      console.log(JSON.stringify(dsList));
      if (dsList.success) {
        // cleanup old backups if they're on the system
        const bkupDs = `${dataset}.TEST.BKUP`;
        const bkupList = await files.List.dataSetsMatchingPattern(this.session, [bkupDs]);
        if (bkupList.success) {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const match = bkupList.apiResponse.find((ds: any) => ds.dsname === bkupDs);
          if (match != null) {
            await files.Delete.dataSet(this.session, bkupDs);
          }
        }
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const matchedItem = dsList.apiResponse.find((ds: any) => ds.dsname === dataset);
        console.log(`Search: ${dataset} | Matched: ${matchedItem}`);
        if (matchedItem == null) {
          this.trackedFiles.push({
            srcFile: dataset,
            tmpFile: null, // null indicates there is no 'restore' op later
            type: FileType.DS_NON_CLUSTER,
          });
        } else {
          await files.Rename.dataSet(this.session, dataset, bkupDs, {});
          this.trackedFiles.push({
            srcFile: dataset,
            tmpFile: bkupDs,
            type: FileType.DS_NON_CLUSTER,
          });
        }
      }
    } catch (error) {
      console.log('[TestRunner] Error trying to rename dataset. ' + error);
      console.log(`[TestRunner] Input dataset: ${dataset}`);
      console.log(
        `[TestRunner] !!!IMPORTANT!!! Tests will continue to run so 
        cleanup can be run post-test, but will likely have invalid results.`,
      );
    }
  }

  public async removeUssFileOrDirForTest(filePath: string) {
    const flattenedTmpName = filePath.replaceAll('/', '_');
    await this.runRaw(`mkdir -p ${this.REMOTE_TEST_TMP_DIR}`);
    await this.runRaw(`mv ${filePath} ${this.REMOTE_TEST_TMP_DIR}/${flattenedTmpName}`);
    this.trackedFiles.push({
      srcFile: filePath,
      tmpFile: `${this.REMOTE_TEST_TMP_DIR}/${flattenedTmpName}`,
      type: FileType.USS_FILE,
    });
  }

  public addCleanFn(replaceFn: (output: string) => string) {
    this.cleanFns.push(replaceFn);
  }

  private cleanOutput(stdout: string, customJobHeaders: string[]): string {
    let cleanedOutput = stdout;
    // user-supplied
    this.cleanFns.forEach((fn) => {
      cleanedOutput = fn(cleanedOutput);
    });

    // generic replacement of sensitive data based on user config
    if (REMOTE_SYSTEM_INFO.sensitiveDataToMask != null && REMOTE_SYSTEM_INFO.sensitiveDataToMask.length > 0) {
      REMOTE_SYSTEM_INFO.sensitiveDataToMask.forEach((data) => {
        const maskTarget = data.key;
        const maskValue = this.getMask(data.type);
        cleanedOutput = cleanedOutput.replaceAll(new RegExp(maskTarget, 'gi'), maskValue);
      });
    }

    const LINES_TO_DELETE = [/(\n^\s*ACF0C038.*?$)$/gim];
    // delete lines
    LINES_TO_DELETE.forEach((pattern) => {
      cleanedOutput = cleanedOutput.replace(pattern, '');
    });

    // custom job headers
    for (let i = 0; i < customJobHeaders.length; i++) {
      const header = customJobHeaders[i];
      const replacePattern = i === 0 ? '\n' : '';
      const HEADER_REMOVAL_PATTERN = new RegExp(`(//|)\\s*${escapeStringRegexp(header)}\\s*\n`, 'gm');
      cleanedOutput = cleanedOutput.replaceAll(HEADER_REMOVAL_PATTERN, replacePattern);
    }

    // built-in
    return cleanedOutput
      .replace(/(JOB[0-9]{5})/gim, 'JOB00000')
      .replaceAll(REMOTE_SYSTEM_INFO.zosJavaHome, '/test/java/home')
      .replaceAll(REMOTE_SYSTEM_INFO.zosNodeHome, '/test/node/home')
      .replaceAll(REMOTE_SYSTEM_INFO.ussTestDir, '/test/dir')
      .replaceAll(`${REMOTE_SYSTEM_INFO.prefix}`, 'TEST.DATASET.PFX')
      .replaceAll(`${this.session.ISession.user}`, 'TESTUSR0')
      .replace(/\/tmp\/\.zweenv-\d{1,5}/g, '/tmp/.zweenv-0000')
      .replace(/\/tmp\/zwe-\d{1,5}/g, '/tmp/zwe-0000')
      .replaceAll(REMOTE_SYSTEM_INFO.volume, 'TSTVOL')
      .replaceAll(REMOTE_SYSTEM_INFO.hostname, this.dummyHostname)
      .replaceAll(REMOTE_SYSTEM_INFO.zosmfPort, this.dummyPort);
  }

  public getMask(maskType: string): string {
    switch (maskType) {
      case 'hostname':
      case 'host':
        return this.dummyHostname;
      case 'sysname':
        return 'SYS0';
      case 'port':
        return this.dummyPort;
      default:
        return '******';
    }
  }

  /**
   * If the file at filePath already exists, this will write a copy with an index attached.
   *  e.g. myfile.txt, myfile.txt.0, myfile.txt.1.
   *
   * Returns the final write destination.
   *
   * @param filePath
   * @param content
   * @returns
   */
  private writeRedundant(filePath: string, content: string): string {
    let tgtFile = filePath;
    const iter = 0;
    // TODO: replace with single readDir, find highest idx, write to idx+1
    while (fs.existsSync(tgtFile) && iter < 1000) {
      tgtFile = `${tgtFile}.${iter}`;
    }
    fs.writeFileSync(tgtFile, content);
    return tgtFile;
  }

  public async runZweTestWithDefaults(
    zoweYaml: ZoweYamlType,
    defaultYaml: ZoweYamlType,
    zweCommand: string,
    cwd: string = REMOTE_SYSTEM_INFO.ussTestDir,
  ): Promise<TestOutput> {
    await this.uploadDefaultsYaml(defaultYaml);
    return this.runZweTest(zoweYaml, zweCommand, cwd);
  }

  public async uploadDefaultsYaml(defaultsYaml: ZoweYamlType): Promise<string> {
    const testName = expect.getState().currentTestName.replace(/\s/g, '_');
    const yamlUploadPath = `${REMOTE_SYSTEM_INFO.ussTestDir}/files/defaults.yaml`;
    const stringDefaultYaml = YAML.stringify(defaultsYaml, { nullStr: '' });
    const yamlOutputDir = this.yamlOutputTemplate.replace('{{ testInstance }}', testName);
    fs.mkdirpSync(yamlOutputDir);
    await this.removeUssFileOrDirForTest('files/defaults.yaml');
    const redundantFilePath = this.writeRedundant(`${yamlOutputDir}/defaults.yaml`, stringDefaultYaml);
    await files.Upload.fileToUssFile(this.session, redundantFilePath, yamlUploadPath, {
      binary: false,
    });
    return yamlUploadPath;
  }

  public async uploadZoweYaml(
    zoweYaml: ZoweYamlType,
    addCustomJobHeaders: boolean = true,
    cwd: string = REMOTE_SYSTEM_INFO.ussTestDir,
  ): Promise<string> {
    const testName = expect.getState().currentTestName.replace(/\s/g, '_');
    let finalZoweYaml = zoweYaml;
    if (addCustomJobHeaders) {
      finalZoweYaml = this.addAnyCustomJobStatements(zoweYaml).yaml;
    }
    const stringZoweYaml = YAML.stringify(finalZoweYaml, { nullStr: '' });
    const uploadPath = `${cwd}/zowe.test.yaml`;
    const yamlOutputDir = this.yamlOutputTemplate.replace('{{ testInstance }}', testName);
    fs.mkdirpSync(yamlOutputDir);
    const redundantFilePath = this.writeRedundant(`${yamlOutputDir}/zowe.yaml`, stringZoweYaml);
    await files.Upload.fileToUssFile(this.session, redundantFilePath, uploadPath, {
      binary: false,
    });
    return uploadPath;
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
    let defaultConfig = `--config ${REMOTE_SYSTEM_INFO.ussTestDir}/zowe.test.yaml`;
    if (this.containsConfigString(zweCommand)) {
      defaultConfig = ''; // the runCommand's ${command} will have the config
    }
    const finalZwe = this.addAnyCustomJobStatements(zoweYaml);
    await this.uploadZoweYaml(finalZwe.yaml, false, cwd);
    const start = performance.now();
    const output = await this.uss.runCommand(`./bin/zwe ${command} ${defaultConfig}`, cwd);
    // default per-test should always be off. If you want tty, run this.useTty() in a beforeEach() block
    const end = performance.now();
    const duration = end - start;
    this.totalRuntime += duration;
    this.totalRuns++;
    this.maxRuntime = Math.max(this.maxRuntime, duration);
    const matches = output.consoleLog.matchAll(/([A-Za-z0-9]{4,8})\((JOB[0-9]{1,5})\) completed with RC=(.*)$/gim);

    // for each match, 0=full matched string, 1=jobname, 2=jobid, 3=rc
    for (const match of matches) {
      fs.appendFileSync(TEST_JOBS_RUN_FILE, `${match[1]}:${match[2]}\n`);
      this.trackedJobs.push({
        jobname: match[1],
        jobid: match[2],
      });
    }
    const cleanedOutput = this.cleanOutput(output.consoleLog, finalZwe.headers);

    return {
      stdout: output.consoleLog,
      cleanedStdout: cleanedOutput,
      rc: output.rc,
    };
  }

  private addAnyCustomJobStatements(zoweYaml: ZoweYamlType): { yaml: ZoweYamlType; headers: string[] } {
    const jclHeader = zoweYaml.zowe?.setup?.jcl?.header;
    // jclHeader is either an array or string, so .length works in both cases
    // @ts-expect-error incomplete schema
    if (jclHeader != null && jclHeader.length > 0) {
      return { yaml: zoweYaml, headers: [] };
    }
    const positionals = REMOTE_SYSTEM_INFO.customJclParms?.positional;
    const keywords = REMOTE_SYSTEM_INFO.customJclParms?.keywords;
    const cloneYaml = _.cloneDeep(zoweYaml);
    let fullParams = '';
    if (positionals != null && positionals.length > 0) {
      fullParams += positionals.join(',');
    }

    if (keywords != null && keywords.length > 0) {
      if (fullParams.length > 0) {
        fullParams += ',';
      }
      fullParams += keywords.join(',');
    }

    const jclLines = this.convertParamsToLines(fullParams);
    if (cloneYaml.zowe?.setup?.jcl?.header == null) {
      _.set(cloneYaml, 'zowe.setup.jcl.header', []);
    }
    cloneYaml.zowe.setup.jcl.header = jclLines;
    return { yaml: cloneYaml, headers: jclLines };
  }

  private convertParamsToLines(params: string): string[] {
    const jclLines = [];
    if (params.length > 70) {
      const lastComma = params.substring(0, 70).lastIndexOf(',');
      const first = params.substring(0, lastComma + 1);
      const secondary = params.substring(lastComma + 1);
      jclLines.push(first);
      jclLines.push(...this.convertParamsToLines(secondary));
    } else {
      jclLines.push(params);
    }

    return jclLines;
  }

  // checks for --config or -c followed by space or =. Not restrictive.
  //  OK: --config myconfig
  //  OK: -c=myconfig
  //  OK: -c
  //  Still OK: -c =
  private containsConfigString(zweCommand: string): boolean {
    return /(--config|(?<!-)-c)[\s+|=]/gim.test(zweCommand);
  }
}

type TrackedFile = {
  srcFile: string;
  tmpFile: string;
  type: FileType;
};

export type TestOutput = {
  stdout: string;
  cleanedStdout: string;
  rc: number;
};
