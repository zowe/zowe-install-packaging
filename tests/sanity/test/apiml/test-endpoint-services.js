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

let request = testUtils.verifyAndSetupEnvironment();
let authenticationCookie;

describe('test endpoint /services and its authentication', function() {

  before('obtain JWT token', async () => {
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
    const uuid = testUtils.uuid();
    authenticationCookie = await testUtils.login(uuid);
  });

  describe('should be able get list of services', () => {
  });
  it('with authenticated user', async () => {
    const uuid = testUtils.uuid();
    let response;
    try {
      response = await request.get('/gateway/services', {
        headers: {
          'Cookie': authenticationCookie
        }
      });
      testUtils.logResponse(uuid, response);
    } catch (error) {
      testUtils.logResponse(uuid, error.response);
      response = error.response;
    }

    expect(response).to.have.property('status');
    expect(response.status).to.equal(200);
    expect(response.data).to.be.an('array').that.is.not.empty;
    expect(response.data.map(x => x.serviceId)).to.include.members(['gateway', 'discovery']);
  });

  describe('should be able get list of services, routed version', () => {
  });
  it('with authenticated user', async () => {
    const uuid = testUtils.uuid();
    let response;
    try {
      response = await request.get('/gateway/api/v1/services/', {
        headers: {
          'Cookie': authenticationCookie
        }
      });
      testUtils.logResponse(uuid, response);
    } catch (error) {
      testUtils.logResponse(uuid, error.response);
      response = error.response;
    }

    expect(response).to.have.property('status');
    expect(response.status).to.equal(200);
    expect(response.data).to.be.an('array').that.is.not.empty;
    expect(response.data.map(x => x.serviceId)).to.include.members(['gateway', 'discovery']);
  });

});
