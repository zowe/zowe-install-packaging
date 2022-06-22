/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2019
 */

const _ = require('lodash');
const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:explorer:docs');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

let REQ, username, password;

describe('test explorer(s) api docs', function() {
  before('verify environment variables', function() {
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    expect(process.env.ZOWE_EXTERNAL_HOST, 'ZOWE_EXTERNAL_HOST is empty').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;

    const baseURL = `https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}/api/v1/apicatalog/apidoc`;
    REQ = axios.create({
      baseURL,
      timeout: 30000,
    });
    username = process.env.SSH_USER;
    password = process.env.SSH_PASSWD;
    debug(`Explorer(s) API swagger json base URL: ${baseURL}`);
  });

  it('should be able to access jobs swagger json', function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/jobs',
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
        expect(res.headers).to.have.property('content-type');
        expect(res.headers['content-type']).to.equal('application/json');
        expect(res.data).to.have.property('openapi');
      });
  });

  it('should be able to access datasets swagger json', function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/datasets',
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
        expect(res.headers).to.have.property('content-type');
        expect(res.headers['content-type']).to.equal('application/json');
        expect(res.data).to.have.property('openapi');
      });
  });

  it('should be able to access unixfiles swagger json', function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/unixfiles',
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
        expect(res.headers).to.have.property('content-type');
        expect(res.headers['content-type']).to.equal('application/json');
        expect(res.data).to.have.property('openapi');
      });
  });

});
