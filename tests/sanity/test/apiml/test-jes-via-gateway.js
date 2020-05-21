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

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

describe('test jes with authentication via gateway', function() {
  before('verify environment variables', function() {
    request = testUtils.verifyAndSetupEnvironment();
  });

  it('Get jobs for the current SSH User via gateway', async () => {
    const uuid = testUtils.uuid();
    const authenticationCookie = await testUtils.login(uuid);

    const username = process.env.SSH_USER;
    testUtils.log(uuid, ` URL: /api/v2/jobs?owner=${username.toUpperCase()}&prefix=*`);
    const response = await request.get(`/api/v2/jobs?owner=${username.toUpperCase()}&prefix=*`, {
      headers: {
        'Cookie': authenticationCookie,
        'X-CSRF-ZOSMF-HEADER': '*'
      }
    });
    testUtils.logResponse(uuid, response);

    expect(response.status).to.equal(200);
    expect(response.data).to.not.be.empty;
  });
});
