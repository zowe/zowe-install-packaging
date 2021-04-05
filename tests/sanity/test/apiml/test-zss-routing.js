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

describe('test zss can be routed via gateway', function() {
  before('verify environment variables', function() {
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    request = testUtils.verifyAndSetupEnvironment();
  });

  it('call zss plugins endpoint', async () => {
    const uuid = testUtils.uuid();
    let response;
    try {
      response = await request.get('/zss/api/v1/plugins');
    } catch(ex) {
      testUtils.log(uuid, ex);
      testUtils.logResponse(uuid, response);
    }

    assertNotEmptyValidResponse(response);
  });
});
