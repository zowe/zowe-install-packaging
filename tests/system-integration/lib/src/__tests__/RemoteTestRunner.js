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
exports.RemoteTestRunner = void 0;
const zowe_1 = require("../zowe");
const uss = __importStar(require("../uss"));
const constants_1 = require("../constants");
const files = __importStar(require("@zowe/zos-files-for-zowe-sdk"));
const fs = __importStar(require("fs-extra"));
const YAML = __importStar(require("yaml"));
class RemoteTestRunner {
    RemoteTestRunner() {
        console.log('init');
        this.session = (0, zowe_1.getZosmfSession)();
    }
    /**
     *
     * @param zoweYaml
     * @param zweCommand
     * @param cwd
     */
    runTest(zoweYaml_1, zweCommand_1) {
        return __awaiter(this, arguments, void 0, function* (zoweYaml, zweCommand, cwd = constants_1.REMOTE_TEST_DIR) {
            let command = zweCommand.trim();
            if (command.startsWith('zwe')) {
                command = command.replace(/zwe/, '');
            }
            const testName = expect.getState().currentTestName;
            const stringZoweYaml = YAML.stringify(zoweYaml);
            fs.writeFileSync(`${constants_1.TEST_YAML_DIR}/zowe.yaml.${testName}`, stringZoweYaml);
            yield files.Upload.bufferToUssFile(this.session, `${constants_1.REMOTE_TEST_DIR}/zowe.test.yaml`, Buffer.from(stringZoweYaml), {
                binary: false,
            });
            const output = yield uss.runCommand(`./bin/zwe ${command} --config  ${constants_1.REMOTE_TEST_DIR}/zowe.test.yaml`, cwd);
            return {
                stdout: output.data,
                rc: output.rc,
            };
        });
    }
}
exports.RemoteTestRunner = RemoteTestRunner;
