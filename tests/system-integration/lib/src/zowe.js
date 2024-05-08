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
Object.defineProperty(exports, "__esModule", { value: true });
exports.getZosmfSession = void 0;
const imperative_1 = require("@zowe/imperative");
const constants_1 = require("./constants");
let cachedZosmfSession;
function getZosmfSession() {
    console.log('called get zosmf');
    if (cachedZosmfSession != null) {
        console.log('returning cached 1' + cachedZosmfSession);
        return cachedZosmfSession;
    }
    const sessCfg = {
        hostname: constants_1.REMOTE_CONNECTION.host,
        port: constants_1.REMOTE_CONNECTION.zosmf_port,
        user: constants_1.REMOTE_CONNECTION.user,
        password: constants_1.REMOTE_CONNECTION.password,
        rejectUnauthorized: constants_1.REMOTE_CONNECTION.zosmf_reject_unauthorized,
        protocol: 'https',
    };
    imperative_1.ConnectionPropsForSessCfg.resolveSessCfgProps(sessCfg, { $0: '', _: [] }, {});
    cachedZosmfSession = new imperative_1.Session(sessCfg);
    console.log('returning not cached ' + cachedZosmfSession);
    return cachedZosmfSession;
}
exports.getZosmfSession = getZosmfSession;
