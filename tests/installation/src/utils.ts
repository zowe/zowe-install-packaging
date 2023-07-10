/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

import * as util from 'util';
import { spawn, SpawnOptions } from 'child_process';
import * as crypto from 'crypto';
import { pathExistsSync, ensureDirSync, copySync, removeSync  } from 'fs-extra';
import * as path from 'path';
import Debug from 'debug';
const debug = Debug('zowe-install-test:utils');

import {
  ZOWE_FMID,
  ANSIBLE_ROOT_DIR,
  SANITY_TEST_REPORTS_DIR,
  INSTALL_TEST_REPORTS_DIR,
} from './constants';

/**
 * Sleep for certain time
 * @param {Integer} ms 
 */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

/**
 * Check if there are any mandatory environment variable is missing.
 * 
 * @param {Array} vars     list of env variable names
 */
export function checkMandatoryEnvironmentVariables(vars: string[]): void {
  for (const v of vars) {
    expect(process.env).toHaveProperty(v);
  }
}

/**
 * Generate MD5 hash of a variable
 *
 * @param {Any} obj        any object
 */
export function calculateHash(obj: any): string {
  return crypto.createHash('md5').update(util.format('%j', obj)).digest('hex');
}

/**
 * Copy sanity test report to install test report folder for future publish.
 *
 * @param {String} reportHash      report hash
 */
export function copySanityTestReport(reportHash: string): void {
  debug(`Copy sanity test report of ${reportHash}`);
  if (pathExistsSync(path.resolve(SANITY_TEST_REPORTS_DIR, 'junit.xml'))) {
    debug(`Found junit.xml in ${SANITY_TEST_REPORTS_DIR}`);
    const targetReportDir: string = path.resolve(INSTALL_TEST_REPORTS_DIR, `${reportHash}`);
    debug(`- copy to ${targetReportDir}`);
    ensureDirSync(targetReportDir);
    copySync(SANITY_TEST_REPORTS_DIR, targetReportDir);
  } else {
    debug(`junit.xml NOT found in ${SANITY_TEST_REPORTS_DIR}`);
  }
}

/**
 * Clean up sanity test report directory for next test
 */
export function cleanupSanityTestReportDir(): void {
  debug(`Clean up sanity test reports directory: ${SANITY_TEST_REPORTS_DIR}`);
  removeSync(SANITY_TEST_REPORTS_DIR);
  ensureDirSync(SANITY_TEST_REPORTS_DIR);
}

/**
 * Import extra vars for Ansible playbook from environment variables.
 * 
 * @param {Object} extraVars      Object
 * @param {String} serverId       String
 */
export function importDefaultExtraVars(extraVars: {[key: string]: any}, serverId: string): void {
  const defaultMapping: {[key: string]: string[]} = {
    'ansible_ssh_host'           : ['SSH_HOST'],
    'ansible_port'               : ['SSH_PORT'],
    'ansible_user'               : ['SSH_USER'],
    'ansible_password'           : ['SSH_PASSWORD'],
    'zos_node_home'              : ['ZOS_NODE_HOME'],
    'zowe_sanity_test_debug_mode': ['SANITY_TEST_DEBUG'],
  };
  const serverIdSanitized = serverId.replace(/[^A-Za-z0-9]/g, '_').toUpperCase();
  defaultMapping['ansible_ssh_host'].push(`${serverIdSanitized}_SSH_HOST`);
  defaultMapping['ansible_port'].push(`${serverIdSanitized}_SSH_PORT`);
  defaultMapping['ansible_user'].push(`${serverIdSanitized}_SSH_USER`);
  defaultMapping['ansible_password'].push(`${serverIdSanitized}_SSH_PASSWORD`);

  Object.keys(defaultMapping).forEach((item) => {
    for (const k of defaultMapping[item]) {
      if (process.env[k] && !extraVars[item]) {
        extraVars[item] = process.env[k];
      }
    }
  });
}

type PlaybookResponse = {
  reportHash: string;
  code: number | null;
  stdout: string;
  stderr: string;
  error?: Error;
};

/**
 * Run Ansible playbook
 *
 * @param  {String}    testcase 
 * @param  {String}    playbook
 * @param  {String}    serverId
 * @param  {Object}    extraVars
 * @param  {String}    verbose
 */
export function runAnsiblePlaybook(testcase: string, playbook: string, serverId: string, extraVars: {[key: string]: any} = {}, verbose = '-v'): Promise<PlaybookResponse> {
  return new Promise((resolve, reject) => {
    const result: PlaybookResponse = {
      reportHash: calculateHash(testcase),
      code: null,
      stdout: '',
      stderr: '',
    };
    // import default vars
    if (!extraVars) {
      extraVars = {};
    }
    importDefaultExtraVars(extraVars, serverId);
    const params = [
      '-l', serverId,
      playbook,
      process.env.ANSIBLE_VERBOSE || verbose,
      `--extra-vars`,
      util.format('%j', extraVars),
    ];
    const opts: SpawnOptions = {
      cwd: ANSIBLE_ROOT_DIR,
      stdio: 'inherit',
    };

    debug(`Playbook ${playbook} started with parameter: ${util.format('%j', params)}`);
    const pb = spawn('ansible-playbook', params, opts);

    pb.on('error', (err) => {
      process.stderr.write('Child Process Error: ' + err);
      result.error = err;

      reject(result);
    });

    pb.on('close', (code) => {
      result.code = code;

      if (code === 0) {
        resolve(result);
      } else {
        reject(result);
      }
    });
  });
}

async function verifyZowe(testcase: string, serverId: string, extraVars: {[key: string]: any} = {}): Promise<PlaybookResponse> {
  debug(`run verify.yml on ${serverId}`);
  let resultVerify;

  try {
    resultVerify = await runAnsiblePlaybook(
      testcase,
      'verify.yml',
      serverId,
      extraVars
    );
  } catch (e) {
    resultVerify = e;
  }
  expect(resultVerify).toHaveProperty('reportHash');

  return resultVerify;
}

/**
 * Install and verify a Zowe build
 *
 * @param  {String}    testcase 
 * @param  {String}    installPlaybook
 * @param  {String}    serverId
 * @param  {Object}    extraVars
 */
async function installAndVerifyZowe(testcase: string, installPlaybook: string, serverId: string, extraVars: {[key: string]: any} = {}): Promise<void> {
  debug(`installAndVerifyZowe(${testcase}, ${installPlaybook}, ${serverId}, ${JSON.stringify(extraVars)})`);

  debug(`run ${installPlaybook} on ${serverId}`);
  const resultInstall = await runAnsiblePlaybook(
    testcase,
    installPlaybook,
    serverId,
    extraVars
  );

  expect(resultInstall.code).toBe(0);

  // sleep extra 2 minutes
  debug(`wait extra 2 min before sanity test`);
  await sleep(120000);

  // clean up sanity test folder
  cleanupSanityTestReportDir();

  if (extraVars && extraVars['skip_start'] && extraVars['skip_start'] === 'true') {
    debug(`running ${installPlaybook} playbook with skip_start=true, skip verify`);

  } else {
    // verify zowe instance with sanity test
    const resultVerify = await verifyZowe(testcase, serverId, {});

    // copy sanity test result to install test report folder
    copySanityTestReport(resultVerify.reportHash);

    expect(resultVerify.code).toBe(0);
  }
}

async function installExtension(testcase: string, serverId: string, extraVars: {[key: string]: any} = {}): Promise<void> {
  debug(`run install-ext.yml on ${serverId}`);
  const resultInstall = await runAnsiblePlaybook(
    testcase,
    'install-ext.yml',
    serverId,
    {
      'zowe_ext_url': extraVars['zowe_ext_url']
    }
  );
  
  expect(resultInstall.stderr).toBe('');
}

async function startZowe(testcase: string, serverId: string): Promise<void> {

  debug(`start zowe on ${serverId}`);
  const resultStop = await runAnsiblePlaybook(
    testcase,
    'start.yml',
    serverId,
    {}
  );

  expect(resultStop.code).toBe(0);

}

async function stopZowe(testcase: string, serverId: string): Promise<void> {

  debug(`stop zowe on ${serverId}`);
  const resultStop = await runAnsiblePlaybook(
    testcase,
    'stop.yml',
    serverId,
    {}
  );

  expect(resultStop.code).toBe(0);

}

async function restartZowe(testcase: string, serverId: string): Promise<void> {

  await stopZowe(testcase, serverId);

  // sleep extra 2 minutes
  debug(`wait extra 2 min before sanity test`);
  await sleep(120000);

  await startZowe(testcase, serverId);

}

async function verifyExtension(testcase: string, serverId: string, extraVars: {[key: string]: any} = {}): Promise<PlaybookResponse> {
  debug(`run verify-ext.yml on ${serverId}`);
  // FIXME: how to verify in v2?
  let resultVerify;
  try {
    resultVerify = await runAnsiblePlaybook(
      testcase,
      'verify-ext.yml',
      serverId,
      {
        'component_id': extraVars['component_id']
      }
    );
  } catch (e) {
    resultVerify = e;
  }
  expect(resultVerify.code).toBe(0);
  return resultVerify;
}

/**
 * Install and verify convenience build
 *
 * @param  {String}    testcase 
 * @param  {String}    serverId
 * @param  {Object}    extraVars
 */
export async function installAndVerifyConvenienceBuild(testcase: string, serverId: string, extraVars: {[key: string]: any} = {}): Promise<void> {
  await installAndVerifyZowe(testcase, 'install.yml', serverId, extraVars);
}

/**
 * Install and verify docker build
 *
 * @param  {String}    testcase 
 * @param  {String}    serverId
 * @param  {Object}    extraVars
 */
export async function installAndVerifyDockerBuild(testcase: string, serverId: string, extraVars: {[key: string]: any} = {}): Promise<void> {
  debug(`installAndVerifyDockerBuild(${testcase}, ${serverId}, ${JSON.stringify(extraVars)})`);

  debug(`run install-docker.yml on ${serverId}`);
  const resultInstall = await runAnsiblePlaybook(
    testcase,
    'install-docker.yml',
    serverId,
    extraVars
  );

  expect(resultInstall.code).toBe(0);

  // sleep extra 2 minutes
  debug(`wait extra 2 min before sanity test`);
  await sleep(120000);

  // clean up sanity test folder
  cleanupSanityTestReportDir();

  if (extraVars && extraVars['skip_start'] && extraVars['skip_start'] === 'true') {
    debug('running install-docker.yml playbook with skip_start=true, skip verify');

  } else {
    // verify zowe instance with sanity test
    const resultVerify = await verifyZowe(testcase, serverId, extraVars);

    // copy sanity test result to install test report folder
    copySanityTestReport(resultVerify.reportHash);

    expect(resultVerify.code).toBe(0);
  }
}

/**
 * Install and verify SMPE FMID
 *
 * @param  {String}    testcase 
 * @param  {String}    serverId
 * @param  {Object}    extraVars
 */
export async function installAndVerifySmpeFmid(testcase: string, serverId: string, extraVars: {[key: string]: any} = {}): Promise<void> {
  await installAndVerifyZowe(testcase, 'install-fmid.yml', serverId, extraVars);
}

export async function installAndVerifyExtension(testcase: string, serverId: string, extraVars: {[key: string]: any} = {}): Promise<void> {
  debug(`installAndVerifyExtension(${testcase}, ${serverId}, ${JSON.stringify(extraVars)})`);

  await installExtension(testcase, serverId, extraVars);

  await restartZowe(testcase, serverId);

  // clean up sanity test folder
  cleanupSanityTestReportDir();

  // const resultVerify = await verifyExtension(testcase, serverId, extraVars);
  // expect(resultVerify).toHaveProperty('reportHash');

  // verify zowe instance with sanity test
  const resultVerify = await verifyZowe(testcase, serverId, {});
  expect(resultVerify).toHaveProperty('reportHash');

  // copy sanity test result to install test report folder
  copySanityTestReport(resultVerify.reportHash);

  expect(resultVerify.code).toBe(0);
}

/**
 * Install and verify SMPE PTF. Separate variables for FMID and PTF install operations.
 *
 * @param  {String}    testcase 
 * @param  {String}    serverId
 * @param  {Object}    extraFmidVars
 * @param  {Object}    extraPtfVars
 */
export async function installAndVerifySmpePtf(testcase: string, serverId: string, 
  extraFmidVars: {[key: string]: any} = {}, 
  extraPtfVars: {[key: string]: any} = {}): Promise<void> {
  debug(`installAndVerifySmpePtf(${testcase}, ${serverId}, FMID: ${JSON.stringify(extraFmidVars)}, PTF: ${JSON.stringify(extraPtfVars)})`);

  debug(`run install-fmid.yml on ${serverId}`);
 
  const resultFmid = await runAnsiblePlaybook(
    testcase,
    'install-fmid.yml',
    serverId,
    {
      'zowe_build_remote': ZOWE_FMID,
      'skip_start': 'true',
      ...extraFmidVars
    }
  );

  expect(resultFmid.code).toBe(0);

  debug(`run install-ptf.yml on ${serverId}`);
  const resultPtf = await runAnsiblePlaybook(
    testcase,
    'install-ptf.yml',
    serverId,
    extraPtfVars
  );

  expect(resultPtf.code).toBe(0);

  // sleep extra 2 minutes
  debug(`wait extra 2 min before sanity test`);
  await sleep(120000);

  // clean up sanity test folder
  cleanupSanityTestReportDir();

  if (extraPtfVars && extraPtfVars['skip_start'] && extraPtfVars['skip_start'] === 'true') {
    debug('running install-ptf.yml playbook with skip_start=true, skip verify');

  } else {
    // verify zowe instance with sanity test
    const resultVerify = await verifyZowe(testcase, serverId, {});

    // copy sanity test result to install test report folder
    copySanityTestReport(resultVerify.reportHash);

    expect(resultVerify.code).toBe(0);
  }
}

/**
 * Install Zowe and generate Swagger API definitions
 * @param testcase
 * @param serverId 
 * @param extraVars 
 */
export async function installAndGenerateApiDocs(testcase: string, serverId: string, extraVars: {[key: string]: any} = {}): Promise<void> {
  debug(`installAndGenerateApiDocs(${testcase}, install.yml, ${serverId}, ${JSON.stringify(extraVars)})`);

  debug(`run install.yml on ${serverId}`);
  const resultInstall = await runAnsiblePlaybook(
    testcase,
    'install.yml',
    serverId,
    extraVars
  );

  expect(resultInstall.code).toBe(0);

  // sleep extra 2 minutes
  debug(`wait extra 2 min before sanity test`);
  await sleep(120000);

  // clean up sanity test folder
  cleanupSanityTestReportDir();

  debug(`run api-generation.yml on ${serverId}`);
  let resultVerify;
  try {
    resultVerify = await runAnsiblePlaybook(
      testcase,
      'api-generation.yml',
      serverId
    );
  } catch (e) {
    resultVerify = e;
  }
  expect(resultVerify).toHaveProperty('reportHash');

  // copy sanity test result to install test report folder
  copySanityTestReport(resultVerify.reportHash);

  expect(resultVerify.code).toBe(0);
}

/**
 * Show all Zowe runtime logs
 *
 * @param  {String}    serverId
 * @param  {Object}    extraVars
 */
export async function showZoweRuntimeLogs(serverId: string, extraVars: {[key: string]: any} = {}): Promise<void> {
  debug(`showZoweRuntimeLogs(${serverId}, ${JSON.stringify(extraVars)})`);

  debug(`run show_logs on ${serverId}`);
  try {
    await runAnsiblePlaybook(
      'doesn\'t matter',
      'show-logs.yml',
      serverId,
      extraVars
    );
  } catch (e) {
    debug(`showZoweRuntimeLogs failed: ${e}`);
  }
}
