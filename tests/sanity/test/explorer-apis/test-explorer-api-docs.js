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

describe('test explorer(s) api docs', function() {

  let hq;

  before('verify environment variables', function() {
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;

    hq = new HTTPRequest(`https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}/apicatalog/api/v1/apidoc`, null, null, {
      username: process.env.SSH_USER,
      password: process.env.SSH_PASSWD,
    });
  });


  it('should be able to access jobs swagger json', async function() {
    const res = await hq.request({
      url: '/jobs',
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.headers).to.have.property('content-type');
    expect(res.headers['content-type']).to.equal('application/json');
    expect(res.data).to.have.property('openapi');
  });

  it('should be able to access datasets swagger json', async function() {
    const res = await hq.request({
      url: '/datasets',
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.headers).to.have.property('content-type');
    expect(res.headers['content-type']).to.equal('application/json');
    expect(res.data).to.have.property('openapi');
  });

  it('should be able to access unixfiles swagger json', async function() {
    const res = await hq.request({
      url: '/unixfiles',
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.headers).to.have.property('content-type');
    expect(res.headers['content-type']).to.equal('application/json');
    expect(res.data).to.have.property('openapi');
  });
});
