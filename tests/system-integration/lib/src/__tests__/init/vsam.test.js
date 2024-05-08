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
const RemoteTestRunner_1 = require("../RemoteTestRunner");
const ZoweYaml_1 = require("../ZoweYaml");
const testSuiteName = 'Dummy tests';
describe(testSuiteName, () => {
    let testRunner;
    beforeEach(() => {
        testRunner = new RemoteTestRunner_1.RemoteTestRunner();
    });
    it('a test', () => __awaiter(void 0, void 0, void 0, function* () {
        console.log('heres a log');
        const cfgYaml = ZoweYaml_1.ZoweYaml.basicZoweYaml();
        cfgYaml.java.home = '/ZOWE/node/J21.0_64/';
        const result = yield testRunner.runTest(cfgYaml, '--help');
        expect(result.rc).toBe(0);
        expect(result.stdout).not.toBeNull();
        expect(result.stdout).toMatchSnapshot();
    }));
});
