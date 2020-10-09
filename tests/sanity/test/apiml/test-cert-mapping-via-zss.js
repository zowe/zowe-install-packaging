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

let assertNotEmptyValidResponse = (response) => {
  expect(response.status).to.equal(200);
  expect(response.data).to.not.be.empty;
};

describe('test zss x509 certificate mapping via zss endpoint', function() {
  before('verify environment variables', function() {
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    request = testUtils.verifyAndSetupEnvironmentForZss();
  });

  it('with valid certificate', async () => {

    let x509Certificate = process.env.ZOWE_CLIENT_CERT;
    const uuid = testUtils.uuid();
    testUtils.log(uuid, 'URL: /certificate/x509/map');
    let authenticationCookie = await request.post('/certificate/x509/map', x509Certificate);

    const username = process.env.SSH_USER;
    testUtils.log(uuid, ` URL: /api/v1/jobs?owner=${username.toUpperCase()}&prefix=*`);
    const response = await request.get(`/api/v2/jobs?owner=${username.toUpperCase()}&prefix=*`, {
      headers: {
        'Cookie': authenticationCookie,
        'X-CSRF-ZOSMF-HEADER': '*'
      }
    });
    testUtils.logResponse(uuid, response);

    assertNotEmptyValidResponse(response);
  });
});
