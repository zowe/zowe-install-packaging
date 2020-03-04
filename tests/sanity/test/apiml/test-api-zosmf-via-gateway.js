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
const debug = require('debug')('test:apiml:gateway');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

let REQ, username, password;
let cookies = {};
const APIML_AUTH_COOKIE = 'apimlAuthenticationToken';

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

describe('test api mediation layer zosmf api', function() {
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

  it('should be able to login to z/OS', function() {
    const _this = this;
    const req = {
      method: 'POST',
      url: '/api/v1/apicatalog/auth/login',
      headers: { 'content-type': 'application/json' },
      data: {
        username,
        password,
      }
    };
    debug('request', req);

    return REQ.request(req)
      .then(function(res) {
        const conciseRes = _.pick(res, ['status', 'statusText', 'headers', 'data']);
        debug('response', conciseRes);
        addContext(_this, {
          title: 'http response',
          value: conciseRes
        });

        expect(res).to.have.property('status');
        // before APIML 1.1.7, the auth endpoint will return 200
        // after APIML 1.1.7, the auth endpoint will return 204
        expect(res.status).to.be.oneOf([200, 204]);
        expect(res.headers).to.be.an('object');
        expect(res.headers).to.have.property('set-cookie');
        expect(res.data).to.be.empty;

        for (let one of res.headers['set-cookie']) {
          const trunks = one.split(/;/).map(trunk => trunk.trim());
          let cookie = null;
          for (let i in trunks) {
            const kv = trunks[i].split(/=/);
            if (`${i}` === '0') {
              if (kv.length === 2) {
                cookie = kv[0];
                cookies[cookie] = {
                  value: kv[1],
                };
              } else {
                debug(`unknown cookie: ${trunks[i]}`);
              }
            } else if (cookie) {
              if (kv.length === 2) {
                cookies[cookie][kv[0]] = kv[1];
              } else if (kv.length === 1) {
                cookies[cookie][kv[0]] = true;
              } else {
                debug(`unknown cookie: ${trunks[i]}`);
              }
            }
          }
        }
        debug(`cookies: ${JSON.stringify(cookies)}`);

        expect(cookies).to.include.any.keys(APIML_AUTH_COOKIE);
      });
  });

  it('should be able to get z/OS Info via the gateway port and endpoint (/api/v1/zosmf/info)', function() {
    if (!cookies || !cookies[APIML_AUTH_COOKIE]) {
      this.skip();
    }

    const _this = this;
    const req = {
      method: 'get',
      url: '/api/v1/zosmf/info',
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${cookies[APIML_AUTH_COOKIE].value}`,
        'X-CSRF-ZOSMF-HEADER': '*'
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
        expect(res.data).to.have.property('api_version');
        expect(res.data).to.have.property('plugins');
        expect(res.data).to.have.property('zosmf_full_version');
        expect(res.data).to.have.property('zos_version');
      })
      .catch(err => {
        const res = err && err.response;
        debug('response', JSON.stringify(_.pick(res, ['status', 'statusText', 'headers', 'data'])));
        expect(err).to.be.null;
      });
  });
});
