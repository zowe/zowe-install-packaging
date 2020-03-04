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
const debug = require('debug')('test:explorer:api-system');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

let REQ, username, password;

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

// NOTICE for skipping test: the endpoint has been removed after migration
describe.skip('test explorer server system api', function() {
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

  it('should be able to get system version (/api/v1/system/version)', function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/api/v1/system/version',
      auth: {
        username,
        password,
      },
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
        expect(res.data).to.have.property('version');
        debug(`Current explorer server version is "${res.data.version}"`);
      });
  });

});
