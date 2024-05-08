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
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculateHash = exports.checkMandatoryEnvironmentVariables = exports.sleep = void 0;
const util = __importStar(require("util"));
const crypto = __importStar(require("crypto"));
/**
 * Sleep for certain time
 * @param {Integer} ms
 */
function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}
exports.sleep = sleep;
/**
 * Check if there are any mandatory environment variable is missing.
 *
 * @param {Array} vars     list of env variable names
 */
function checkMandatoryEnvironmentVariables(vars) {
    for (const v of vars) {
        if (!Object.keys(process.env).includes(v)) {
            throw new Error(`Expected to find a value for ${v} in process.env`);
        }
    }
}
exports.checkMandatoryEnvironmentVariables = checkMandatoryEnvironmentVariables;
/**
 * Generate MD5 hash of a variable
 *
 * @param {Any} obj        any object
 */
function calculateHash(obj) {
    return crypto.createHash('md5').update(util.format('%j', obj)).digest('hex');
}
exports.calculateHash = calculateHash;
