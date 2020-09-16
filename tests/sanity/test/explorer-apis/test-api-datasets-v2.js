/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const expect = require('chai').expect;
const utils = require('../apiml/utils');

let REQ;
const TEST_DATASET_PATTERN = 'SYS1.LINKLIB*';
const TEST_DATASET_NAME = 'SYS1.LINKLIB';
const TEST_DATASET_MEMBER_NAME = 'ACCOUNT';

describe('test explorer server datasets api', function() {
  before('verify environment variables', function() {
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    // sets up a request variable and retrieves the authentication needed for v2 APIs
    REQ = utils.verifyAndSetupEnvironment();
  });

  it(`should be able to list data sets of ${TEST_DATASET_PATTERN} (v2 API)`, async() => {
    const uuid = utils.uuid();
    const authenticationCookie = await utils.login(uuid);

    utils.log(uuid, ' URL: /api/v2/datasets/' + encodeURIComponent(TEST_DATASET_PATTERN));
    const res = await REQ.get('/api/v2/datasets/' + encodeURIComponent(TEST_DATASET_PATTERN), {
      headers: {
        'Cookie': authenticationCookie,
        'X-CSRF-ZOSMF-HEADER': '*'
      }
    });
    utils.logResponse(uuid, res);

    expect(res).to.have.property('status');
    expect(res.status).to.equal(200);
    expect(res.data.items).to.be.a('array');
    expect(res.data.items.map(one => one.name)).to.include(TEST_DATASET_NAME);
  });

  it(`should be able to get members of data set ${TEST_DATASET_NAME} (v2 API)`, async() => {
    const uuid = utils.uuid();
    const authenticationCookie = await utils.login(uuid);

    utils.log(uuid, ' URL: /api/v2/datasets/' + encodeURIComponent(TEST_DATASET_NAME) + '/members');
    const res = await REQ.get('/api/v2/datasets/' + encodeURIComponent(TEST_DATASET_NAME) + '/members', {
      headers: {
        'Cookie': authenticationCookie,
        'X-CSRF-ZOSMF-HEADER': '*'
      }
    });
    utils.logResponse(uuid, res);

    expect(res).to.have.property('status');
    expect(res.status).to.equal(200);
    expect(res.data).to.be.an('object');
    expect(res.data).to.have.property('items');
    expect(res.data.items).to.be.an('array');
    expect(res.data.items).to.include(TEST_DATASET_MEMBER_NAME);
  });

  it(`should be able to get content of data set ${TEST_DATASET_NAME} (v2 API)`, async() => {
    const uuid = utils.uuid();
    const authenticationCookie = await utils.login(uuid);

    utils.log(uuid, ' URL: /api/v2/datasets/' + encodeURIComponent(`${TEST_DATASET_NAME}(${TEST_DATASET_MEMBER_NAME})`) + '/content');
    const res = await REQ.get('/api/v2/datasets/' + encodeURIComponent(`${TEST_DATASET_NAME}(${TEST_DATASET_MEMBER_NAME})`) + '/content', {
      headers: {
        'Cookie': authenticationCookie,
        'X-CSRF-ZOSMF-HEADER': '*'
      }
    });
    utils.logResponse(uuid, res);

    expect(res).to.have.property('status');
    expect(res.status).to.equal(200);
    expect(res.data).to.be.an('object');
    expect(res.data).to.have.property('records');
    expect(res.data.records).to.be.a('string');
  });
});
