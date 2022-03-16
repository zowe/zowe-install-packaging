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
const { HTTPRequest, HTTP_STATUS } = require('../http-helper');

const zosHost = process.env.ZOWE_ZOS_HOST || process.env.ZOWE_EXTERNAL_HOST;
// FIXME: zss is static registered and registration information are not shared to Discovery running off Z.
//        so disable this test if Gateway/Discovery host and z/OS host are not same.
const skipTest = process.env.ZOWE_EXTERNAL_HOST !== zosHost;

(skipTest ? describe.skip : describe)('test zss can be routed via gateway', function() {

  let hq;

  before('verify environment variables', function() {
    hq = new HTTPRequest();
  });

  it('call zss plugins endpoint', async function() {
    const res = await hq.request({
      url: '/zss/api/v1/plugins',
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.not.be.empty;
  });
});
