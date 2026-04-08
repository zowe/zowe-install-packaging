/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import { assertEqualsStrict } from './common/assert';
import * as template from '@bin/libs/template';
import * as common from '@bin/libs/common';

common.printMessage("Starting 'template.resolveString' test cases.");
const testCases = [
  { templateString: undefined, data: { does: "not matter" }, expected: undefined },
  { templateString: 'Hello, ${this.name}!', data: { name: 'Alice' }, expected: 'Hello, Alice!' },
  { templateString: 'The sum of ${this.a} and ${this.b} is ${this.a + this.b}.', data: { a: 5, b: 3 }, expected: 'The sum of 5 and 3 is 8.' },
  { templateString: 'This is a test with no placeholders.', data: {}, expected: 'This is a test with no placeholders.' },
  { templateString: 'Undefined variable: ${this.undefinedVar}', data: {}, expected: 'Undefined variable: undefined' },
  { templateString: 'Null variable: ${this.nullVar}', data: { nullVar: null }, expected: 'Null variable: null' },
  { templateString: '//ZWEJOB JOB ${this.zowe.setup.jcl.header}', data: { zowe: { setup: { jcl: { header: '123456' } } } }, expected: '//ZWEJOB JOB 123456' },
  { 
    templateString: "//ZWESIS01  PROC NAME='ZWESIS_STD',MEM=${this.zowe.setup.dataset.parmlibMembers.zis.substring(6)},RGN=0M,OPT=''",
    data: { zowe: { setup: { dataset: { parmlibMembers: { zis: 'ZWESIP$@' } } } } },
    expected: "//ZWESIS01  PROC NAME='ZWESIS_STD',MEM=$@,RGN=0M,OPT='"
  },
];

for (const test of testCases) {
  const result = template.resolveString(test.templateString, test.data);
  assertEqualsStrict(result, test.expected);  
}
