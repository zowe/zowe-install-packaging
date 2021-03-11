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
const https = require('https');
const fs = require('fs');
const utils = require('./utils.js');
let request;
const httpsAgent = new https.Agent({
  rejectUnauthorized: false,
  cert: fs.readFileSync('../../playbooks/roles/configure/files/USER-cert.cer'),
  key: fs.readFileSync('../../playbooks/roles/configure/files/USER-PRIVATEKEY.key'),
});

let key = 'testKey';
let value = 'testValue';

const testUtils = require('./utils');
const CACHING_PATH = '/cachingservice/api/v1/cache';
const cachingServiceEnabled = process.env.ZOWE_CACHING_SERVICE_START !== undefined && process.env.ZOWE_CACHING_SERVICE_START == 'true';

let assertStatusCodeCreated = (response) => {
  utils.logResponse('Assert created', response);
  expect(response.status).to.equal(201);
};

let assertStatusCodeOk = (response) => {
  utils.logResponse('Assert ok', response);
  expect(response.status).to.equal(200);
  expect(response.data).to.not.be.empty;
};

let assertStatusNoContent = (response) => {
  utils.logResponse('Assert no content', response);
  expect(response.status).to.equal(204);
};

(cachingServiceEnabled ? describe : describe.skip)('test caching service via gateway', function() {
  before('verify environment variables', function () {
    utils.log('Caching path', 'Caching Service Test Begin');
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
    request = testUtils.verifyAndSetupEnvironment();
    utils.log('Caching path', CACHING_PATH);
  });

  describe('should be able to use caching service ', () => {
    it('to store a key', async () => {

      const response = await request.post(CACHING_PATH, {
        key, value
      },{ httpsAgent });

      assertStatusCodeCreated(response);
    });

    it('to get a key', async () => {
      const response = await request.get(CACHING_PATH + '/' + key, { httpsAgent });

      assertStatusCodeOk(response);
    });

    it('to update the key value', async () => {
      value = 'newKey';
      const putResponse = await request.put(CACHING_PATH, {
        key, value
      }, { httpsAgent });
      utils.log('Put response', putResponse);

      const response = await request.get(CACHING_PATH + '/' + key, { httpsAgent });

      assertStatusCodeOk(response);
    });

    it('to delete the key', async () => {
      const response = await request.delete(CACHING_PATH + '/' + key, { httpsAgent });

      assertStatusNoContent(response);
    });
  });
});
