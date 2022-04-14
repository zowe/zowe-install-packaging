/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

/*eslint no-console: ["error", { allow: ["log", "warn", "error"] }] */

const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:cli:jobs');
const fs = require('fs');
const util = require('util');
const fsAccess = util.promisify(fs.access);
// const addContext = require('mochawesome/addContext');

const { execZoweCli, defaultZOSMFProfileName, createDefaultZOSMFProfile } = require('./utils');

const EXPLORER_API_TEST_DATASET_PATTERN = 'SYS1.LINKLIB*';
const EXPLORER_API_TEST_DATASET_NAME = 'SYS1.LINKLIB';
const EXPLORER_API_TEST_DATASET_MEMBER_NAME = 'ACCOUNT';

describe(`cli list data sets of ${EXPLORER_API_TEST_DATASET_PATTERN}`, function() {
  before('verify environment variables', async function() {
    expect(process.env.ZOSMF_PORT, 'ZOSMF_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOWE_EXTERNAL_HOST, 'ZOWE_EXTERNAL_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;

    const result = await createDefaultZOSMFProfile(
      process.env.ZOWE_EXTERNAL_HOST,
      process.env.ZOSMF_PORT,
      process.env.SSH_USER,
      process.env.SSH_PASSWD
    );

    debug('result:', result);

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    expect(result.stdout).to.be.empty;
  });

  it(`should have an data set of ${EXPLORER_API_TEST_DATASET_NAME}`, async function() {
    const result = await execZoweCli(`zowe zos-files list data-set "${EXPLORER_API_TEST_DATASET_PATTERN}" --response-format-json --zosmf-profile ${defaultZOSMFProfileName}`);

    debug('result:', result);
    // addContext(this, {
    //   title: 'cli result',
    //   value: result
    // });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    const res = JSON.parse(result.stdout);
    expect(res).to.be.an('object');
    expect(res.success).to.be.true;
    expect(res.data).to.be.an('object');
    expect(res.data.success).to.be.true;
    expect(res.data.apiResponse).to.be.an('object');
    expect(res.data.apiResponse.items).to.be.an('array');
    const dsIndex = res.data.apiResponse.items.findIndex(item => item.dsname === EXPLORER_API_TEST_DATASET_NAME);
    debug(`found ${EXPLORER_API_TEST_DATASET_NAME} at ${dsIndex}`);
    expect(dsIndex).to.be.above(-1);
  });

  it(`should be able to download file ${EXPLORER_API_TEST_DATASET_NAME}(${EXPLORER_API_TEST_DATASET_MEMBER_NAME})`, async function() {
    const targetFile = '.tmp/' + EXPLORER_API_TEST_DATASET_NAME.replace(/\./g, '-') + '-' + EXPLORER_API_TEST_DATASET_MEMBER_NAME;
    const result = await execZoweCli(`zowe zos-files download data-set '${EXPLORER_API_TEST_DATASET_NAME}(${EXPLORER_API_TEST_DATASET_MEMBER_NAME})' --file "${targetFile}" --response-format-json --zosmf-profile ${defaultZOSMFProfileName}`);

    debug('result:', result);
    // addContext(this, {
    //   title: 'cli result',
    //   value: result
    // });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    const res = JSON.parse(result.stdout);
    expect(res).to.be.an('object');
    expect(res.success).to.be.true;
    expect(res.data).to.be.an('object');
    expect(res.data.success).to.be.true;
    expect(res.data.commandResponse).to.be.a('string');
    expect(res.data.commandResponse).to.include('Data set downloaded successfully');
    expect(res.data.apiResponse).to.be.a('object');

    // file should exist
    await fsAccess(targetFile, fs.constants.R_OK);
  });
});
