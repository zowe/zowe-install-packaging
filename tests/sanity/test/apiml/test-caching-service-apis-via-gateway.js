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
let request;
let key = 'testKey';
let value = 'testValue';
let authenticationCookie;

const testUtils = require('./utils');
const CACHING_PATH = '/cachingservice/api/v1/cache';

let assertStatusCodeCreated = (response) => {
  expect(response.status).to.equal(201);
};

let assertStatusCodeOk = (response) => {
  expect(response.status).to.equal(200);
  expect(response.data).to.not.be.empty;
};

let assertStatusNoContent = (response) => {
  expect(response.status).to.equal(204);
};

let getToken = async () => {
  const uuid = testUtils.uuid();
  testUtils.log(uuid, 'ZOWE_CACHING_SERVICE_START value ' + process.env.ZOWE_CACHING_SERVICE_START);
  return await testUtils.login(uuid);
};

describe('test caching service via gateway', function() {
  before('verify environment variables', function () {
    if (process.env.ZOWE_CACHING_SERVICE_START == 'false') {
      this.skip();
    }
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
    request = testUtils.verifyAndSetupEnvironment();
  });

  describe('should be able to use caching service ', () => {
    it('to store a key', async () => {
      authenticationCookie = await getToken();
      const response = await request.post(CACHING_PATH, {
        key, value
      },
      {
        headers: {
          'Cookie': authenticationCookie,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });

      assertStatusCodeCreated(response);
    });

    it('to get a key', async () => {
      authenticationCookie = await getToken();
      const response = await request.get(CACHING_PATH + '/' + key,
        {
          headers: {
            'Cookie': authenticationCookie,
            'X-CSRF-ZOSMF-HEADER': '*'
          }
        });

      assertStatusCodeOk(response);
    });

    it('to update the key value', async () => {
      authenticationCookie = await getToken();
      value = 'newKey';
      await request.put(CACHING_PATH, {
        key, value
      },
      {
        headers: {
          'Cookie': authenticationCookie,
          'X-CSRF-ZOSMF-HEADER': '*'
        }
      });

      const response = await request.get(CACHING_PATH + '/' + key,
        {
          headers: {
            'Cookie': authenticationCookie,
            'X-CSRF-ZOSMF-HEADER': '*'
          }
        });

      assertStatusCodeOk(response);
    });

    it('to delete the key', async () => {
      authenticationCookie = await getToken();
      const response = await request.delete(CACHING_PATH + '/' + key,
        {
          headers: {
            'Cookie': authenticationCookie,
            'X-CSRF-ZOSMF-HEADER': '*'
          }
        });

      assertStatusNoContent(response);
    });
  });
});
