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
const fs = require('fs');
const https = require('https');
const {
  DEFAULT_CLIENT_CERTIFICATE,
  DEFAULT_CLIENT_CERTIFICATE_PRIVATE_KEY,
} = require('../constants');

describe('test caching service via gateway', function() {

  let hq;
  let httpsAgent;

  let key = 'testKey';
  let value = 'testValue';
  const CACHING_PATH = '/cachingservice/api/v1/cache';
  
  before('verify environment variables', function() {
    hq = new HTTPRequest();

    httpsAgent = new https.Agent({
      rejectUnauthorized: false,
      cert: fs.readFileSync(DEFAULT_CLIENT_CERTIFICATE),
      key: fs.readFileSync(DEFAULT_CLIENT_CERTIFICATE_PRIVATE_KEY),
    });
  });

  describe('should be able to use caching service ', function() {
    it('to store a key', async function() {
      const res = await hq.request({
        url: CACHING_PATH,
        method: 'post',
        data: {
          key, value
        },
        httpsAgent
      });

      expect(res.status).to.equal(HTTP_STATUS.CREATED);
    });

    it('to get a key', async function() {
      const res = await hq.request({
        url: CACHING_PATH + '/' + key,
        httpsAgent
      });

      expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
      expect(res.data).to.not.be.empty;
    });

    it('to update the key value', async function() {
      value = 'newKey';
      const resPut = await hq.request({
        url: CACHING_PATH,
        method: 'put',
        data: { key, value },
        httpsAgent
      });

      expect(resPut.status).to.equal(HTTP_STATUS.NO_CONTENT);
      expect(resPut.data).to.be.empty;

      const res = await hq.request({
        url: CACHING_PATH + '/' + key,
        httpsAgent
      });

      expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
      expect(res.data).to.not.be.empty;
    });

    it('to delete the key', async function() {
      const res = await hq.request({
        url: CACHING_PATH + '/' + key,
        method: 'delete',
        httpsAgent
      });

      expect(res.status).to.equal(HTTP_STATUS.NO_CONTENT);
      expect(res.data).to.be.empty;
    });
  });
});
