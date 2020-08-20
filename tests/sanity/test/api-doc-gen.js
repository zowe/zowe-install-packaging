/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const util = require('util');
const exec = util.promisify(require('child_process').exec);
const request = util.promisify(require('request'));
const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:api-doc-gen');

const illegalCharacterRegex = /'/gm;
const isolatedDoubleBackSlashRegex = /(?<!\\\\)\\\\(?!\\\\)/gm;
const testSuiteName = 'Generate api documentation';
const apiDefFolderPath = '../../api_definitions';
const apiDefinitionsMap = [
  { 'name': 'datasets', 'port': process.env.ZOWE_EXPLORER_DATASETS_PORT },
  { 'name': 'jobs', 'port': process.env.ZOWE_EXPLORER_JOBS_PORT },
  //TODO zlux api? {'name': 'zlux', 'port': process.env.ZOWE_ZLUX_HTTPS_PORT},
  //TODO zosmf api? {'name': 'zosmf', 'port': process.env.ZOSMF_PORT},
  //TODO catalog and gateway api? { 'name': 'apiml', 'port': process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT }
];

describe(testSuiteName, () => {
  before('verify environment variables', function () {
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.ZOWE_EXPLORER_DATASETS_PORT, 'ZOWE_EXPLORER_DATASETS_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOWE_EXPLORER_JOBS_PORT, 'ZOWE_EXPLORER_JOBS_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ZLUX_HTTPS_PORT, 'ZOWE_ZLUX_HTTPS_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOSMF_PORT, 'ZOSMF_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;
  });

  it('Generate Swagger API files', async () => {
    // Acquire API definitions and store in api_definitions directory
    await cleanApiDefDirectory();
    await captureApiDefinitions();
  });
});

async function cleanApiDefDirectory() {
  debug('Clean api_definitions directory.');
  await exec(`if [ -d "$${apiDefFolderPath}" ]; then rm -R $${apiDefFolderPath}/*; fi`);
}

async function captureApiDefinitions() {
  for (let apiDef of apiDefinitionsMap) {
    let url = `https://${process.env.SSH_HOST}:${apiDef.port}/v2/api-docs`;
    debug(`Capture API Swagger definition for ${apiDef.name} at ${url}`);
    let res = await request(url);
    let swaggerJsonString = res.body.replace(illegalCharacterRegex, '').replace(isolatedDoubleBackSlashRegex, '');
    await exec(`echo '${swaggerJsonString}' > ${apiDefFolderPath}/${apiDef.name}.json`);
  }
}
