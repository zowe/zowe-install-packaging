/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

const expect = require('chai').expect;
const { HTTPRequest, HTTP_STATUS, APIMLAuth } = require('../http-helper');
const { APIML_AUTH_COOKIE } = require('../constants');

describe('test api mediation layer logout functionality', function() {

  let hq;
  let apiml;

  const assertLogout = async (authenticationHeader) => {
    const beforeStatus = await apiml.checkLoginStatus(authenticationHeader);
    expect(beforeStatus).to.equal(HTTP_STATUS.SUCCESS);
    const logoutResponse = await apiml.logout(authenticationHeader);
    expect(logoutResponse.status).to.equal(HTTP_STATUS.NO_CONTENT);
    const afterStatus = await apiml.checkLoginStatus(authenticationHeader);
    expect(afterStatus).to.equal(HTTP_STATUS.UNAUTHORIZED);
  };

  before('verify environment variables', function() {
    hq = new HTTPRequest();
    apiml = new APIMLAuth(hq);
  });

  it('should login to the system and properly logout with Bearer', async function() {
    const token = await apiml.login();

    const authenticationHeader = {
      'Authorization': 'Bearer ' + token
    };

    await assertLogout(authenticationHeader);
  });

  it('should login to the system and properly logout using Cookie', async function() {
    const token = await apiml.login();

    const authenticationHeader = {
      'Cookie': `${APIML_AUTH_COOKIE}=${token}`
    };

    await assertLogout(authenticationHeader);
  });
});
