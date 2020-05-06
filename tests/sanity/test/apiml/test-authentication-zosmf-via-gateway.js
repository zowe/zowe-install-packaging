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
const debug = require('debug')('zowe-sanity-test:apiml:gateway');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

let REQ, username, password;
let cookies = {};
const APIML_AUTH_COOKIE = 'apimlAuthenticationToken';

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

describe('test api mediation layer zosmf authentication', function() {
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

  it('should be able to get data from ZOSM/f with valid basic header', () => {

  });

  it('should be able to get data from ZOSM/f with valid cookie', () => {

  });

  it('should be able to get data from ZOSM/f with valid LTPA cookie', () => {

  });

  it('should be able to get data from ZOSM/f with valid JWT token', () => {

  });
});
