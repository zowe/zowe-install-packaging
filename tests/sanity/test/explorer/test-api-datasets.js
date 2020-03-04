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
const debug = require('debug')('test:explorer:api-datasets');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

let REQ, username, password;
const TEST_DATASET_PATTERN = 'SYS1.LINKLIB*';
const TEST_DATASET_NAME = 'SYS1.LINKLIB';
const TEST_DATASET_MEMBER_NAME = 'ACCOUNT';

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

describe('test explorer server datasets api', function() {
  before('verify environment variables', function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;

    REQ = axios.create({
      baseURL: `https://${process.env.SSH_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`,
      timeout: 30000,
    });
    username = process.env.SSH_USER;
    password = process.env.SSH_PASSWD;
    debug(`Explorer server URL: https://${process.env.SSH_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`);
  });

  it(`should be able to list data sets of ${TEST_DATASET_PATTERN}`, function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/api/v1/datasets/' + encodeURIComponent(TEST_DATASET_PATTERN),
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
        expect(res.data.items).to.be.an('array');
        expect(res.data.items.map(one => one.name)).to.include(TEST_DATASET_NAME);
      });
  });

  it(`should be able to get members of data set ${TEST_DATASET_NAME}`, function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/api/v1/datasets/' + encodeURIComponent(TEST_DATASET_NAME) + '/members',
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
        expect(res.data).to.have.property('items');
        expect(res.data.items).to.be.an('array');
        expect(res.data.items).to.include(TEST_DATASET_MEMBER_NAME);
      });
  });

  it(`should be able to get content of data set ${TEST_DATASET_NAME}`, function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/api/v1/datasets/' + encodeURIComponent(`${TEST_DATASET_NAME}(${TEST_DATASET_MEMBER_NAME})`) + '/content',
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
        expect(res.data).to.have.property('records');
        expect(res.data.records).to.be.a('string');
      });
  });
});
