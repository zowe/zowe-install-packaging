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

const zosHost = process.env.ZOWE_ZOS_HOST || process.env.ZOWE_EXTERNAL_HOST;
// FIXME: zss is static registered and registration information are not shared to Discovery running off Z.
//        so disable this test if Gateway/Discovery host and z/OS host are not same.
const skipTest = process.env.ZOWE_EXTERNAL_HOST !== zosHost;

(skipTest ? describe.skip : describe)('test zss can be routed via gateway', function() {
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
