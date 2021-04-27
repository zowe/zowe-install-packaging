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
const debug = require('debug')('zowe-sanity-test:explorer:api-datasets-v2');
const { handleCompressionRequest } = require('./zlib-helper');

let REQ;
const TEST_DATASET_PATTERN = 'SYS1.LINKLIB*';
const TEST_DATASET_NAME = 'SYS1.LINKLIB';
const TEST_DATASET_MEMBER_NAME = 'ACCOUNT';

describe('test explorer server datasets api v2',async function() {
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

    const req = {
      method: 'get',
      url: '/api/v2/datasets/' + encodeURIComponent(TEST_DATASET_PATTERN),
      headers: {
        'Cookie': authenticationCookie,
        'X-CSRF-ZOSMF-HEADER': '*'
      }
    };
    debug('request', req);

    function verifyResponse(res) {
      expect(res).to.have.property('status');
      expect(res.status).to.equal(200);
      expect(res.data.items).to.be.a('array');
      expect(res.data.items.map(one => one.name)).to.include(TEST_DATASET_NAME);
    }

    debug('list dataset default');
    let res = await REQ.request(req);
    utils.logResponse(uuid, res);
    verifyResponse(res);

    debug('list dataset decompress with zlib');
    res = await handleCompressionRequest(REQ,req);
    utils.logResponse(uuid, res);
    verifyResponse(res);
    
  });

  it(`should be able to get members of data set ${TEST_DATASET_NAME} (v2 API)`, async() => {
    const uuid = utils.uuid();
    const authenticationCookie = await utils.login(uuid);

    utils.log(uuid, ' URL: /api/v2/datasets/' + encodeURIComponent(TEST_DATASET_NAME) + '/members');

    const req = {
      method: 'get',
      url: '/api/v2/datasets/' + encodeURIComponent(TEST_DATASET_NAME) + '/members',
      headers: {
        'Cookie': authenticationCookie,
        'X-CSRF-ZOSMF-HEADER': '*'
      }
    };

    function verifyResponse(res) {
      expect(res).to.have.property('status');
      expect(res.status).to.equal(200);
      expect(res.data).to.be.an('object');
      expect(res.data).to.have.property('items');
      expect(res.data.items).to.be.an('array');
      expect(res.data.items).to.include(TEST_DATASET_MEMBER_NAME);
    }

    debug('list dataset member default');
    let res = await REQ.request(req);
    utils.logResponse(uuid, res);
    verifyResponse(res);

    debug('list dataset member decompress with zlib');
    res = await handleCompressionRequest(REQ,req);
    utils.logResponse(uuid, res);
    verifyResponse(res);

  });

  it(`should be able to get content of a data set member ${TEST_DATASET_NAME}(${TEST_DATASET_MEMBER_NAME}) (v2 API)`, async() => {
    const uuid = utils.uuid();
    const authenticationCookie = await utils.login(uuid);

    utils.log(uuid, ' URL: /api/v2/datasets/' + encodeURIComponent(`${TEST_DATASET_NAME}(${TEST_DATASET_MEMBER_NAME})`) + '/content');
    const req = {
      method: 'get',
      url:'/api/v2/datasets/' + encodeURIComponent(`${TEST_DATASET_NAME}(${TEST_DATASET_MEMBER_NAME})`) + '/content', 
      headers: {
        'Cookie': authenticationCookie,
        'X-CSRF-ZOSMF-HEADER': '*'
      }
    };
    
    function verifyResponseStatus(res) {
      expect(res).to.have.property('status');
      expect(res.status).to.equal(200);
      
    }

    function verifyResponseData(res) {
      expect(res.data).to.be.an('object');
      expect(res.data).to.have.property('records');
      expect(res.data.records).to.be.a('string');
    }

    debug('list dataset default');
    let res = await REQ.request(req);
    utils.logResponse(uuid, res);
    verifyResponseStatus(res);
    verifyResponseData(res);

    debug('list dataset decompress with zlib');
    res = await handleCompressionRequest(REQ,req,{ungzip: false});
    utils.logResponse(uuid, res);
    verifyResponseStatus(res);

  });
});
