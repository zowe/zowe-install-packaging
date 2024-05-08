/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as util from 'util';
import * as crypto from 'crypto';

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
    if (!Object.keys(process.env).includes(v)) {
      throw new Error(`Expected to find a value for ${v} in process.env`);
    }
  }
}

/**
 * Generate MD5 hash of a variable
 *
 * @param {Any} obj        any object
 */
export function calculateHash(obj: unknown): string {
  return crypto.createHash('md5').update(util.format('%j', obj)).digest('hex');
}
