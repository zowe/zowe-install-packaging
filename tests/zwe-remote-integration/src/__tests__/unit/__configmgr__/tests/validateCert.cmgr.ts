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
import { _unit_test } from '@bin/commands/validate/certificate/index';
import { assertEqualsStrict } from './common/assert';
import * as common from '@bin/libs/common';
/**
 * Test cases for processCertificateAnalyserNonZeroOutput written as unit tests rather than integration tests
 *  since many error conditions require a keyring to be defined on the mainframe system. Unit tests bypass that restriction.
 */

/*const trappedErrors: string[] = [];
const trapErrors = (content: string) => {
  trappedErrors.push(content);
}
Object.assign(common, {printFormattedError: trapErrors});*/
const ZOWE_CONFIG = config.getZoweConfig();
common.printMessage('Starting "processCertificateAnalyserNonZeroOutput" test cases.');
const testCases = [
  {output: 'There is no such provider:', configInvalid: _unit_test.VALIDATION_WARN, certificateInvalid: _unit_test.VALIDATION_OK, errorText: 'Java is unable to read either keystore or truststore due to type.'},
];

for (const test of testCases) {
  const result = _unit_test.processCertificateAnalyserNonZeroOutput(test.output, [], ZOWE_CONFIG, 'JCEKS', 'JCEKS', 'test', 'test', 'test');
 
  assertEqualsStrict(result.configInvalid, test.configInvalid);
  assertEqualsStrict(result.certificateInvalid, test.certificateInvalid);
//  assertContains(trappedErrors.join('\n'), test.errorText);
  
//  trappedErrors.length = 0;
}




