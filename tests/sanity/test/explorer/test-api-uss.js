/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const _ = require('lodash');
const expect = require('chai').expect;
const debug = require('debug')('test:explorer:api-uss');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

let REQ, username, password;
let testDir;
const DIR_TO_TEST = 'uss_explorer';
const FILE_TO_TEST = 'pluginDefinition.json';

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

// NOTICE for skipping test: the endpoint has been removed after migration
describe.skip('test explorer server uss files api', function() {
  before('verify environment variables', function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ROOT_DIR, 'ZOWE_ROOT_DIR is not defined').to.not.be.empty;
    expect(process.env.ZOWE_EXPLORER_SERVER_HTTPS_PORT, 'ZOWE_EXPLORER_SERVER_HTTPS_PORT is not defined').to.not.be.empty;

    REQ = axios.create({
      baseURL: `https://${process.env.SSH_HOST}:${process.env.ZOWE_EXPLORER_SERVER_HTTPS_PORT}`,
      timeout: 30000,
    });
    username = process.env.SSH_USER;
    password = process.env.SSH_PASSWD;
    debug(`Explorer server URL: https://${process.env.SSH_HOST}:${process.env.ZOWE_EXPLORER_SERVER_HTTPS_PORT}`);

    testDir = process.env.ZOWE_ROOT_DIR;
  });

  it(`should be able to list content of directory ${DIR_TO_TEST}`, function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/api/v1/uss/files/' + encodeURIComponent(testDir + '/' + DIR_TO_TEST),
      auth: {
        username,
        password,
      }
    };
    debug('request', req);

    return REQ.request(req)
      .then(function(res) {
        debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
        addContext(_this, {
          title: 'http response',
          value: res && res.data
        });

        expect(res).to.have.property('status');
        expect(res.status).to.equal(200);
        expect(res.data).to.be.an('object');
        expect(res.data).to.include({
          'type': 'directory',
        });
        expect(res.data).to.have.property('children');
        expect(res.data.children).to.be.an('array');
        const findTestFile = res.data.children.findIndex(one => one.name === FILE_TO_TEST);
        debug(`found ${DIR_TO_TEST}/${FILE_TO_TEST} at ${findTestFile}`);
        expect(findTestFile).to.be.above(-1);
      });
  });

  it(`should be able to get content of file ${DIR_TO_TEST}/${FILE_TO_TEST}`, function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/api/v1/uss/files/' + encodeURIComponent(testDir + '/' + DIR_TO_TEST + '/' + FILE_TO_TEST) + '/content',
      auth: {
        username,
        password,
      }
    };
    debug('request', req);

    return REQ.request(req)
      .then(function(res) {
        debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
        addContext(_this, {
          title: 'http response',
          value: res && res.data
        });

        expect(res).to.have.property('status');
        expect(res.status).to.equal(200);
        expect(res.data).to.be.an('object');
        expect(res.data).to.have.property('content');
        expect(res.data.content).to.be.a('string');
        expect(() => {
          JSON.parse(res.data.content);
          debug('content parse successfully');
        }).to.not.throw;
      });
  });
});
