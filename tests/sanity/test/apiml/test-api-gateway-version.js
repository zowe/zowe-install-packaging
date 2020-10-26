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

const targetHost = process.env.ZOWE_NONZOS_HOST || process.env.SSH_HOST;

describe('test api gateway version', function() {
  before('verify environment variables', function() {
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
  
    expect(targetHost, 'targetHost is empty, define ZOWE_NONZOS_HOST || SSH_HOST').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;

    REQ = axios.create({
      baseURL: `https://${targetHost}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`,
      timeout: 30000,
    });
    username = process.env.SSH_USER;
    password = process.env.SSH_PASSWD;
    debug(`Explorer server URL: https://${targetHost}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`);
  });

  it('should return the version information of the API Mediation Layer and Zowe', function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/api/v1/gateway/version',
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
        expect(res.data).to.have.property('apiml');
        expect(res.data.apiml).to.have.property('version');
        expect(res.data.apiml).to.have.property('buildNumber');
        expect(res.data.apiml).to.have.property('commitHash');
      });
  });
});
