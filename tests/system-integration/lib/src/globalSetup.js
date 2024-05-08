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
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const uss = __importStar(require("./uss"));
const files = __importStar(require("@zowe/zos-files-for-zowe-sdk"));
const constants_1 = require("./constants");
const fs = __importStar(require("fs-extra"));
const zowe_1 = require("./zowe");
module.exports = () => __awaiter(void 0, void 0, void 0, function* () {
    // check directories and configmgr look OK
    console.log(`${constants_1.REPO_ROOT_DIR}`);
    if (!fs.existsSync(`${constants_1.REPO_ROOT_DIR}/bin/zwe`)) {
        throw new Error('Could not locate the zwe tool locally. Ensure you are running tests from the test project root');
    }
    const configmgrPax = fs.readdirSync(`${constants_1.THIS_TEST_ROOT_DIR}/.build`).find((item) => /configmgr.*\.pax/g.test(item));
    if (configmgrPax == null) {
        throw new Error('Could not locate a configmgr pax in the .build directory');
    }
    console.log(`Using example-zowe.yaml as base for future zowe.yaml modifications...`);
    fs.copyFileSync(`${constants_1.REPO_ROOT_DIR}/example-zowe.yaml`, constants_1.THIS_TEST_BASE_YAML);
    fs.mkdirpSync(`${constants_1.THIS_TEST_ROOT_DIR}/.build/zowe`);
    fs.mkdirpSync(`${constants_1.TEST_YAML_DIR}`);
    console.log('Setting up remote server...');
    yield uss.runCommand(`mkdir -p ${constants_1.REMOTE_TEST_DIR}`);
    console.log(`Uploading ${configmgrPax} to ${constants_1.REMOTE_TEST_DIR}/configmgr.pax ...`);
    yield files.Upload.fileToUssFile((0, zowe_1.getZosmfSession)(), `${constants_1.THIS_TEST_ROOT_DIR}/.build/${configmgrPax}`, `${constants_1.REMOTE_TEST_DIR}/configmgr.pax`, { binary: true });
    console.log(`Uploading ${constants_1.REPO_ROOT_DIR}/bin to ${constants_1.REMOTE_TEST_DIR}/bin...`);
    yield files.Upload.dirToUSSDirRecursive((0, zowe_1.getZosmfSession)(), `${constants_1.REPO_ROOT_DIR}/bin`, `${constants_1.REMOTE_TEST_DIR}/bin/`, {
        binary: false,
        includeHidden: true,
    });
    console.log(`Unpacking configmgr and placing it in bin/utils ...`);
    yield uss.runCommand(`pax -ppx -rf configmgr.pax && mv configmgr bin/utils/`, `${constants_1.REMOTE_TEST_DIR}`);
    console.log('Remote server setup complete');
});
