/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as config from '@bin/libs/config';
import { _unit_test } from '@bin/commands/internal/start/prepare/index';
import { assertEqualsStrict } from './common/assert';
import * as common from '@bin/libs/common';
import * as std from 'cm_std';

const ZOWE_CONFIG = config.getZoweConfig();
common.printMessage('Starting "getStartupCheckMode" test cases.');
// Each test case sets "default" and the listed checks, then verifies the resolved mode of each listed check.
// A setting of null means the value is not set in zowe.yaml.
// "certificate" has a built-in action of "warn"; "ports" and "zosmf" have a built-in action of "exit".
type Mode = { doCheck: boolean, warnOnly: boolean };
type TestCase = { default: string | null, checks: { [check: string]: [string | null, Mode] } };
const EXIT: Mode = { doCheck: true, warnOnly: false };
const WARN: Mode = { doCheck: true, warnOnly: true };
const DISABLED: Mode = { doCheck: false, warnOnly: false };
const testCases: TestCase[] = [
  // per-check values take precedence over default
  { default: 'exit', checks: { ports: ['warn', WARN], zosmf: ['disabled', DISABLED], certificate: ['exit', EXIT] } },
  // default applies to every check that is not set, including checks with a built-in action
  { default: 'exit', checks: { ports: [null, EXIT], zosmf: [null, EXIT], certificate: [null, EXIT] } },
  { default: 'disabled', checks: { ports: [null, DISABLED], zosmf: [null, DISABLED], certificate: [null, DISABLED] } },
  { default: 'warn', checks: { ports: [null, WARN], zosmf: ['exit', EXIT], certificate: [null, WARN] } },
  // neither default nor the check is set: built-in action applies
  { default: null, checks: { ports: [null, EXIT], zosmf: [null, EXIT], certificate: [null, WARN] } },
  { default: null, checks: { ports: ['disabled', DISABLED], zosmf: ['warn', WARN], certificate: ['exit', EXIT] } },
];

if (!ZOWE_CONFIG.zowe.launchScript) {
  ZOWE_CONFIG.zowe.launchScript = {};
}
if (!ZOWE_CONFIG.zowe.launchScript.startupChecks) {
  ZOWE_CONFIG.zowe.launchScript.startupChecks = {};
}
const startupChecks = ZOWE_CONFIG.zowe.launchScript.startupChecks;

let rc = 0;
for (const test of testCases) {
  startupChecks.default = test.default;
  for (const check of Object.keys(test.checks)) {
    startupChecks[check] = test.checks[check][0];
  }

  for (const check of Object.keys(test.checks)) {
    const expected = test.checks[check][1];
    const mode = _unit_test.getStartupCheckMode(check);
    rc += assertEqualsStrict(mode.doCheck, expected.doCheck);
    rc += assertEqualsStrict(mode.warnOnly, expected.warnOnly);
  }
}

std.exit(rc);




