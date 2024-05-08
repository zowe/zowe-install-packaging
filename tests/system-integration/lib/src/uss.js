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
exports.runCommand = void 0;
const constants_1 = require("./constants");
const zos_uss_for_zowe_sdk_1 = require("@zowe/zos-uss-for-zowe-sdk");
function getSession() {
    return new zos_uss_for_zowe_sdk_1.SshSession({
        hostname: constants_1.REMOTE_CONNECTION.host,
        port: constants_1.REMOTE_CONNECTION.ssh_port,
        user: constants_1.REMOTE_CONNECTION.user,
        password: constants_1.REMOTE_CONNECTION.password,
    });
}
function runCommand(command_1) {
    return __awaiter(this, arguments, void 0, function* (command, cwd = '~') {
        const session = getSession();
        let stdout = '';
        const rc = yield zos_uss_for_zowe_sdk_1.Shell.executeSshCwd(session, command, cwd, (data) => {
            if (data.trim()) {
                stdout += data;
            }
        });
        return { data: stdout, rc: rc };
    });
}
exports.runCommand = runCommand;
