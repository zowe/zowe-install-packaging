/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const debug = require('debug')('zowe-sanity-test:apiml:gateway');
const axios = require('axios');
const expect = require('chai').expect;

const APIML_AUTH_COOKIE = 'apimlAuthenticationToken';
let username, password, request;

let login = async () => {
  let response = await request.post('/api/v1/apicatalog/auth/login', {
    username, password
  });

  // Validate the response at least basically
  expect(response.status).to.be.oneOf([200, 204]);
  expect(response.headers).to.be.an('object');
  expect(response.headers).to.have.property('set-cookie');
  expect(response.data).to.be.empty;

  return findCookieInResponse(response, APIML_AUTH_COOKIE);
};

let findCookieInResponse = (response, cookieName) => {
  let cookiesSetByServer = response.headers['set-cookie'];
  let authenticationCookie = cookiesSetByServer.filter(cookieRow => cookieRow.startsWith(cookieName));
  if(authenticationCookie.length === 0) {
    throw new Error('The authentication was unsuccessful');
  }

  return authenticationCookie[0];
};

let verifyAndSetupEnvironment = () => {
  const environment = process.env;
  expect(environment.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
  expect(environment.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
  expect(environment.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
  expect(environment.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;

  const baseUrl = `https://${environment.SSH_HOST}:${environment.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`;
  request = axios.create({
    baseURL: baseUrl,
    timeout: 30000,
    headers: {
      'Connection': 'Keep-Alive',
      'Accept-Encoding': 'gzip,deflate',
      'X-CSRF-ZOSMF-HEADER': '*'
    }
  });
  debug(`Explorer server URL: ${baseUrl}`);
  username = process.env.SSH_USER;
  password = process.env.SSH_PASSWD;
  return request;
};

module.exports = {
  login,
  findCookieInResponse,
  verifyAndSetupEnvironment
};
