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

const DEFAULT = {
  "zowe": {
    "setup": {
      "dataset": {
        "parmlibMembers": {
          "zis": "ZWESIP00"
        }
      },
      "security": {
        "product": "RACF",
        "groups": {
          "admin": "ZWEADMIN",
          "stc": "ZWEADMIN",
          "sysProg": "ZWEADMIN"
        },
        "users": {
          "zowe": "ZWESVUSR",
          "zis": "ZWESIUSR"
        },
        "stcs": {
          "zowe": "ZWESLSTC",
          "zis": "ZWESISTC",
          "aux": "ZWESASTC"
        }
      },
      "certificate": {
        "type": "PKCS12",
        "pkcs12": {
          "directory": "/var/zowe/keystore",
          "lock": true,
          "name": "localhost",
          "password": "password",
          "caAlias": "local_ca",
          "caPassword": "local_ca_password"
        },
        "dname": {
          "caCommonName": "Zowe Development Instances CA",
          "commonName": "Zowe Development Instances Certificate",
          "orgUnit": "API Mediation Layer",
          "org": "Zowe Sample",
          "locality": "Prague",
          "state": "Prague",
          "country": "CZ"
        },
        "validity": 3650
      },
      "vsam": {
        "name": ""
      },
      "jcl": {
        "header": ""
      }
    },
    "network": {
      "proxyType": "https"
    },
    "configmgr": {
      "validation": "STRICT"
    },
    "job": {
      "name": "ZWE1SV",
      "prefix": "ZWE1"
    },
    "rbacProfileIdentifier": "1",
    "cookieIdentifier": "1",
    "externalPort": 7554,
    "launchScript": {
      "logLevel": "info",
      "onComponentConfigureFail": "warn",
      "startupChecks": {
        "default": "exit"
      }
    },
    "verifyCertificates": "STRICT",
    "sysMessageTrim": false
  }
}

const testCases = [
  { templateString: "", data: { nothing: true }, expected: "" },
  { templateString: ' ', data: { something: null }, expected: ' ' },
  { templateString: 'This is a test with no placeholders.', data: {}, expected: 'This is a test with no placeholders.' },

  { templateString: 'Hello, ${this.name}!', data: { name: 'Alice' }, expected: 'Hello, Alice!' },
  { templateString: 'The sum of ${this.a} and ${this.b} is ${this.a + this.b}.', data: { a: 5, b: 3 }, expected: 'The sum of 5 and 3 is 8.' },
  { templateString: 'Undefined variable: ${this.undefinedVar}', data: {}, expected: 'Undefined variable: undefined' },
  { templateString: 'Null variable: ${this.nullVar}', data: { nullVar: null }, expected: 'Null variable: null' },

  { templateString: "Certificate directory: ${this.zowe.setup.certificate.pkcs12.directory}", data: DEFAULT, expected: "Certificate directory: /var/zowe/keystore" },
  { templateString: "Proxy type: ${this.zowe.network.proxyType}", data: DEFAULT, expected: "Proxy type: https" },
  { templateString: "Validation level: ${this.zowe.configmgr.validation}", data: DEFAULT, expected: "Validation level: STRICT" },
  { templateString: "Job name: ${this.zowe.job.name}", data: DEFAULT, expected: "Job name: ZWE1SV" },
  { templateString: "Launch script log level: ${this.zowe.launchScript.logLevel}", data: DEFAULT, expected: "Launch script log level: info" },

  { templateString: '//ZWEJOB JOB ${this.zowe.setup.jcl.header}', data: { zowe: { setup: { jcl: { header: "'123456',\n//  NOTIFY=&SYSUID" } } } }, expected: `//ZWEJOB JOB '123456',\n//  NOTIFY=&SYSUID` },
  { templateString: "//ZWESIS01  PROC NAME='${this.components.zss.crossMemoryServerName}',MEM=${this.zowe.setup.dataset.parmlibMembers.zis.substring(6)},RGN=0M,OPT=''",
    data: {
      zowe: {
        setup: {
          dataset: {
            parmlibMembers: {
              zis: 'ZWESIP$@'
            }
          }
        }
      },
      components: {
        zss: {
          crossMemoryServerName: 'TEST_TEMPLATES'
        }
      }
    },
    expected: "//ZWESIS01  PROC NAME='TEST_TEMPLATES',MEM=$@,RGN=0M,OPT=''"
  },
];

common.printMessage("Starting 'template.resolveString' test cases.");

for (const test of testCases) {
  const result = template.resolveString(test.templateString, test.data);
  assertEqualsStrict(result, test.expected);
}
