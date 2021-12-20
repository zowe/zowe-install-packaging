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
const debug = require('debug')('zowe-sanity-test:explorer:api-gateway');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

let REQ, username, password;


describe('test api gateway sample extension controller', function() {
  before('verify environment variables', function() {
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    expect(process.env.ZOWE_EXTERNAL_HOST, 'ZOWE_EXTERNAL_HOST is empty').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;

    REQ = axios.create({
      baseURL: `https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`,
      timeout: 30000,
    });
    username = process.env.SSH_USER;
    password = process.env.SSH_PASSWD;
    debug(`Explorer server URL: https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`);
  });

  it('should return the greeting message from the gateway sample extension controller', function() {
    debug('Verify access to greeting endpoint via /api/v1/greeting');
    return getAndVerifyGreeting('/api/v1/greeting');
  });

  function getAndVerifyGreeting(url) {
    const _this = this;

    const req = {
      method: 'get',
      url: url,
      // auth: {
      //   username,
      //   password,
      // }
    };
    debug('request', req);

    return REQ.request(req)
      .then(function(res) {
        addContext(_this, {
          title: 'http response',
          value: res && res.data
        });

        expect(res.status).to.equal(200);
        expect(res.data).to.not.be.empty;
      });
  }
});
