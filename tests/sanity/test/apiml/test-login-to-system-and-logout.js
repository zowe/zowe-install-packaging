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
const testUtils = require('./utils');

let request;
const HttpStatus = {
  SUCCESS: 200,
  UNAUTHORIZED: 401
};

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

let logged = async (headers, expectedStatus) => {
  let status;
  try {
    const response = await request.get('/api/v1/zosmf/restfiles/ds?dslevel=sys1.p*', {
      headers: headers
    });
    status = response.status;
  } catch(err) {
    status = err.response.status;
  }

  expect(status).to.equal(expectedStatus);
};

let logout = async (headers) => {
  const response = await request.post('/api/v1/gateway/auth/logout', {},{
    headers: headers
  });
  expect(response.status).to.equal(204);
};

let assertLogout = async (authorizationHeaders) => {
  await logged(authorizationHeaders, HttpStatus.SUCCESS);
  await logout(authorizationHeaders);
  await logged(authorizationHeaders, HttpStatus.UNAUTHORIZED);
};

describe('test api mediation layer logout functionality', function() {
  before('verify environment variables', function() {
    request = testUtils.verifyAndSetupEnvironment();
  });

  it('should login to the system and properly logout with Bearer', async () => {
    const authenticationCookie = await testUtils.login();
    const jwtToken = authenticationCookie.split(';')[0]
      .split('=')[1];
    const authorizationHeaders = {
      'Authorization': 'Bearer ' + jwtToken
    };

    await assertLogout(authorizationHeaders);
  });

  it('should login to the system and properly logout using Cookie', async () => {
    const authenticationCookie = await testUtils.login();
    const authorizationHeaders = {
      'Cookie': authenticationCookie
    };

    await assertLogout(authorizationHeaders);
  });
});
