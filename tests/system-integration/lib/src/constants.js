"use strict";
/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.REMOTE_CONNECTION = exports.REMOTE_TEST_DIR = exports.CLEANUP_AFTER_TESTS = exports.TEST_JOBS_RUN_FILE = exports.TEST_DATASETS_HLQ = exports.TEST_YAML_DIR = exports.INSTALL_TEST_ROOT_DIR = exports.THIS_TEST_BASE_YAML = exports.THIS_TEST_ROOT_DIR = exports.REPO_ROOT_DIR = exports.ZOWE_FMID = void 0;
const path = __importStar(require("path"));
const util = __importStar(require("./utils"));
const yn_1 = __importDefault(require("yn"));
// import Debug from 'debug';
// const debug = Debug('zowe-install-test:constants');
// the FMID we will use to test PTF
exports.ZOWE_FMID = 'AZWE002';
exports.REPO_ROOT_DIR = path.resolve(__dirname, '../../../');
exports.THIS_TEST_ROOT_DIR = path.resolve(__dirname, '../'); // JEST runs in the src dir
exports.THIS_TEST_BASE_YAML = path.resolve(exports.THIS_TEST_ROOT_DIR, '.build/zowe.yaml.base');
exports.INSTALL_TEST_ROOT_DIR = path.resolve(__dirname, '../');
exports.TEST_YAML_DIR = path.resolve(exports.THIS_TEST_ROOT_DIR, '.build', 'zowe_yaml_tests');
exports.TEST_DATASETS_HLQ = process.env['TEST_DS_HLQ'] || 'ZWETESTS';
exports.TEST_JOBS_RUN_FILE = path.resolve(exports.THIS_TEST_ROOT_DIR, '.build', 'jobs-run.txt');
const cleanup = (0, yn_1.default)(process.env['CLEANUP_AFTER_TESTS']);
exports.CLEANUP_AFTER_TESTS = cleanup != null ? cleanup : true;
const envVars = ['SSH_HOST', 'SSH_PORT', 'SSH_USER', 'SSH_PASSWORD', 'ZOSMF_PORT', 'REMOTE_TEST_ROOT_DIR'];
util.checkMandatoryEnvironmentVariables(envVars);
exports.REMOTE_TEST_DIR = process.env['REMOTE_TEST_ROOT_DIR'] || '/ZOWE/zwe-system-test';
const ru = (0, yn_1.default)(process.env['ZOSMF_REJECT_UNAUTHORIZED']);
exports.REMOTE_CONNECTION = {
    host: process.env['SSH_HOST'],
    ssh_port: Number(process.env['SSH_PORT']),
    zosmf_port: process.env['ZOSMF_PORT'],
    user: process.env['SSH_USER'],
    password: process.env['SSH_PASSWORD'],
    zosmf_reject_unauthorized: ru != null ? ru : false,
};
// debug(`process.env >>>>>>>>>>>>>>>>>>>>>>>>>>\n${JSON.stringify(process.env)}\n<<<<<<<<<<<<<<<<<<<<<<<`);
