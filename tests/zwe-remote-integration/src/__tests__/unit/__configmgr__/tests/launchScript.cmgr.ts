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
const testCases = [
  { default: { setting: 'exit', doCheck: true, warnOnly: false}, ports: { setting: 'warn', doCheck: true, warnOnly: true}, zosmf: { setting: 'disabled', doCheck: false, warnOnly: false}},
  { default: { setting: 'exit', doCheck: true, warnOnly: false}, ports: { setting: null, doCheck: true, warnOnly: false}, zosmf: { setting: null, doCheck: true, warnOnly: false}},
  { default: { setting: 'disabled', doCheck: false, warnOnly: false}, ports: { setting: null, doCheck: false, warnOnly: false}, zosmf: { setting: null, doCheck: false, warnOnly: false}},
  { default: { setting: 'warn', doCheck: true, warnOnly: true}, ports: { setting: null, doCheck: true, warnOnly: true}, zosmf: { setting: 'exit', doCheck: true, warnOnly: false}}
];

let rc = 0;
for (const test of testCases) {
  ZOWE_CONFIG.zowe.launchScript.startupChecks.default = test.default.setting;
  ZOWE_CONFIG.zowe.launchScript.startupChecks.ports = test.ports.setting;
  ZOWE_CONFIG.zowe.launchScript.startupChecks.zosmf = test.zosmf.setting;

  const defaultMode = _unit_test.getStartupCheckMode('default');
  const portsMode = _unit_test.getStartupCheckMode('ports');
  const zosmfMode = _unit_test.getStartupCheckMode('zosmf');

  rc += assertEqualsStrict(defaultMode.doCheck, test.default.doCheck)
  rc += assertEqualsStrict(defaultMode.warnOnly, test.default.warnOnly)

  rc += assertEqualsStrict(portsMode.doCheck, test.ports.doCheck)
  rc += assertEqualsStrict(portsMode.warnOnly, test.ports.warnOnly)

  rc += assertEqualsStrict(zosmfMode.doCheck, test.zosmf.doCheck)
  rc += assertEqualsStrict(zosmfMode.warnOnly, test.zosmf.warnOnly)

}

std.exit(rc);




