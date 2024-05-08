/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as path from 'path';
import * as util from './utils';
import yn from 'yn';
// import Debug from 'debug';
// const debug = Debug('zowe-install-test:constants');

// the FMID we will use to test PTF
export const ZOWE_FMID = 'AZWE002';
export const REPO_ROOT_DIR: string = path.resolve(__dirname, '../../../');
export const THIS_TEST_ROOT_DIR: string = path.resolve(__dirname, '../'); // JEST runs in the src dir
export const THIS_TEST_BASE_YAML: string = path.resolve(THIS_TEST_ROOT_DIR, '.build/zowe.yaml.base');
export const INSTALL_TEST_ROOT_DIR: string = path.resolve(__dirname, '../');
export const TEST_YAML_DIR = path.resolve(THIS_TEST_ROOT_DIR, '.build', 'zowe_yaml_tests');
export const TEST_DATASETS_HLQ = process.env['TEST_DS_HLQ'] || 'ZWETESTS';
export const TEST_JOBS_RUN_FILE = path.resolve(THIS_TEST_ROOT_DIR, '.build', 'jobs-run.txt');

const cleanup = yn(process.env['CLEANUP_AFTER_TESTS']);
export const CLEANUP_AFTER_TESTS = cleanup != null ? cleanup : true;

const envVars = ['SSH_HOST', 'SSH_PORT', 'SSH_USER', 'SSH_PASSWORD', 'ZOSMF_PORT', 'REMOTE_TEST_ROOT_DIR'];
util.checkMandatoryEnvironmentVariables(envVars);

export const REMOTE_TEST_DIR = process.env['REMOTE_TEST_ROOT_DIR'] || '/ZOWE/zwe-system-test';

const ru = yn(process.env['ZOSMF_REJECT_UNAUTHORIZED']);

export const REMOTE_CONNECTION = {
  host: process.env['SSH_HOST'],
  ssh_port: Number(process.env['SSH_PORT']),
  zosmf_port: process.env['ZOSMF_PORT'],
  user: process.env['SSH_USER'],
  password: process.env['SSH_PASSWORD'],
  zosmf_reject_unauthorized: ru != null ? ru : false,
};

// debug(`process.env >>>>>>>>>>>>>>>>>>>>>>>>>>\n${JSON.stringify(process.env)}\n<<<<<<<<<<<<<<<<<<<<<<<`);
