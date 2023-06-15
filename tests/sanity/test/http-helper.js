/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

const _ = require('lodash');
const debug = require('debug')('zowe-sanity-test:http-helper');
const axios = require('axios');
const expect = require('chai').expect;
const zlib = require('zlib');
const fs = require('fs');
const http = require('http');
const https = require('https');
const {
  DEFAULT_HTTP_REQUEST_TIMEOUT,
  APIML_AUTH_COOKIE,
  DEFAULT_CLIENT_CERTIFICATE,
  DEFAULT_CLIENT_CERTIFICATE_PRIVATE_KEY,
} = require('./constants');

const deflate = (dataStream) => new Promise((resolve, reject) => {
  try {
    let gunzip = zlib.createGunzip();
    dataStream.pipe(gunzip);
    gunzip.on('data', function(data) {
      let dataStr = data.toString();
      // content JSON.parse(data.toString()) parsing can cause exception
      resolve(JSON.parse(dataStr));
    });
    gunzip.on('error', function(err) {
      reject(err);
    });
  } catch(err) {
    reject(err);
  }
});

const uuid = () => {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    let r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
};

const HTTP_STATUS = {
  SUCCESS: 200,
  CREATED: 201,
  NO_CONTENT: 204,
  MOVED: 301,
  REDIRECT: 302,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  INETERNAL_ERROR: 500,
};

class HTTPRequest {
  constructor(baseURL, timeout, headers, auth) {
    if (!baseURL) {
      expect(process.env.ZOWE_EXTERNAL_HOST, 'ZOWE_EXTERNAL_HOST is empty').to.not.be.empty;
      expect(process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;
      baseURL = `https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`;
    }
    if (!timeout) {
      timeout = DEFAULT_HTTP_REQUEST_TIMEOUT;
    }

    debug(`HTTPRequest.init with ${baseURL}, headers:`, headers, ', timeout:', timeout);

    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    this._request = axios.create({
      baseURL,
      headers,
      auth,
      timeout,
    });
  }

  async request(config, compressionOptions) {
    let res;
    const _uuid = uuid();
    const reqDebug = debug.extend(_uuid);

    try {
      reqDebug('>>>> request:', config);

      // merge compression options with default values
      const normalizedCompressionOptions =  Object.assign({},{
        manualDecompress: false,
        ungzip: true,
      }, compressionOptions);
      reqDebug('   > compression options:',normalizedCompressionOptions);

      if (normalizedCompressionOptions.manualDecompress) {
        // disable auto decompression
        config.responseType = 'stream';
        config.decompress = false;
        if (!config.headers) {
          config.headers = {};
        }
        config.headers['Accept-Encoding'] = 'gzip';
      }

      res = await this._request.request(config);

      if (normalizedCompressionOptions.manualDecompress && normalizedCompressionOptions.ungzip) {
        res.data = await deflate(res.data);
      }
    } catch (err) {
      reqDebug('   < error:', err.message);
      if (err.response) {
        res = err.response;
      } else {
        throw err;
      }
    }

    const conciseRes = _.pick(res, ['status', 'statusText', 'headers', 'data']);
    reqDebug('   < status:', conciseRes && conciseRes.status, conciseRes && conciseRes.statusText);
    reqDebug('   < headers:', conciseRes && conciseRes.headers);
    if (conciseRes && conciseRes.data) {
      if (conciseRes.data instanceof http.IncomingMessage) {
        reqDebug('   < data: <IncomingMessage> (readable=', conciseRes.data.readable, ', complete=', conciseRes.data.complete, ')');
      } else {
        reqDebug('   < data:', conciseRes.data);
      }
    }

    return res;
  }

  findCookieInResponse(res, cookieName) {
    const cookies = res.headers['set-cookie'];
    if (!cookies) {
      throw new Error('Cannot find set-cookies from response.');
    }

    const cookie = cookies.filter(cookie => cookie.startsWith(cookieName));
    if (cookie.length === 0) {
      throw new Error(`Cannot find cookie ${cookieName} from response.`);
    }

    return cookie[0];
  }
}

class APIMLAuth {

  constructor(httpRequest) {
    this.httpRequest = httpRequest;
  }

  _validateAuthResponse(res) {
    // Validate the response at least basically
    expect(res.status).to.be.oneOf([HTTP_STATUS.SUCCESS, HTTP_STATUS.NO_CONTENT]);
    expect(res.headers).to.be.an('object');
    expect(res.headers).to.have.property('set-cookie');
    expect(res.data).to.be.empty;
  }

  _validateResponse(res, property) {
    // Validate the response at least basically
    expect(res.status).to.be.oneOf([HTTP_STATUS.SUCCESS, HTTP_STATUS.NO_CONTENT]);
    expect(res.headers).to.be.an('object');
    if (property) {
      expect(res.data).to.have.property(property);
    }
  }

  _extractAuthToken(res) {
    const authCookie = this.httpRequest.findCookieInResponse(res, APIML_AUTH_COOKIE);  
    // Example:
    // apimlAuthenticationToken=eyJ????.eyJ??????.dZ?????; Comment=API Mediation Layer security token; Path=/; SameSite=Strict; HttpOnly; Secure;
    const token = authCookie.split(';')[0].split('=')[1];
    if (!token) {
      throw new Error('The authentication was unsuccessful, failed to find authentication token.');
    }

    return token;
  }

  _extractSessionToken(res) {
    const token = res.data['sessionToken'];
    if (!token) {
      throw new Error('The authentication was unsuccessful, failed to extract session token.');
    }
    expect(token).to.be.an('string');
    return token;
  }

  _extractAccessToken(res) {
    let token;
    // Example: <html><response name="access_token" value="tokenvalue1234"/></html>
    const matches = res.data.toString().match(/name="access_token" value="(.*)"/i);
    if (matches.length > 1) {
      token = matches[1];
    }
    if (!token) {
      throw new Error('The authentication was unsuccessful, failed to extract access token.');
    }
    return token;
  }

  async login(username, password) {
    debug('================================= APIMLAuth.login');

    if (!username) {
      expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
      username = process.env.SSH_USER;
    }
    if (!password) {
      expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
      password = process.env.SSH_PASSWD;
    }

    const res = await this.httpRequest.request({
      url: '/gateway/api/v1/auth/login',
      method: 'post',
      data: {
        username,
        password,
      },
    });

    this._validateAuthResponse(res);

    return this._extractAuthToken(res);
  }

  async loginWithCertificate(cert, key) {
    debug('================================= APIMLAuth.loginWithCertificate');

    const httpsAgent = new https.Agent({
      rejectUnauthorized: false,
      cert: fs.readFileSync(cert || DEFAULT_CLIENT_CERTIFICATE),
      key: fs.readFileSync(key || DEFAULT_CLIENT_CERTIFICATE_PRIVATE_KEY),
    });

    const res = await this.httpRequest.request({
      url: '/gateway/api/v1/auth/login',
      method: 'post',
      httpsAgent,
    });

    this._validateAuthResponse(res);

    return this._extractAuthToken(res);
  }

  async loginViaOkta(clientId, username, password) {
    debug('================================= APIMLAuth.loginViaOkta');
    expect(process.env.OKTA_HOSTNAME, 'OKTA_HOSTNAME is empty').to.not.be.empty;
    if (!clientId) {
      expect(process.env.OKTA_CLIENT_ID, 'OKTA_CLIENT_ID is empty').to.not.be.empty;
      clientId = process.env.OKTA_CLIENT_ID;
    }
    if (!username) {
      expect(process.env.OKTA_USER, 'OKTA_USER is not defined').to.not.be.empty;
      username = process.env.OKTA_USER;
    }
    if (!password) {
      expect(process.env.OKTA_PASSWORD, 'OKTA_PASSWORD is not defined').to.not.be.empty;
      password = process.env.OKTA_PASSWORD;
    }

    const oktaHttpReq = new HTTPRequest(`https://${process.env.OKTA_HOSTNAME}`);
    
    const sessionRes = await oktaHttpReq.request({
      url: '/api/v1/authn',
      method: 'post',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      data: {
        username,
        password,
      },
    });

    this._validateResponse(sessionRes, 'sessionToken');
    const sessionToken = this._extractSessionToken(sessionRes);
    const loginUri = 'https://oidcdebugger.com/debug';

    const authRes = await oktaHttpReq.request({
      url: '/oauth2/default/v1/authorize',
      method: 'get',
      params: {
        'client_id': clientId,
        'redirect_uri': loginUri,
        'response_type': 'token',
        'response_mode': 'form_post',
        'sessionToken': sessionToken,
        'scope': 'openid',
        'state': 'SanityTest',
        'nonce': 'SanityTest',
      },
    });

    return this._extractAccessToken(authRes);
  }

  async logout(headers) {
    debug('================================= APIMLAuth.logout');

    const res = await this.httpRequest.request({
      url: '/gateway/api/v1/auth/logout',
      method: 'post',
      headers,
    });

    return res;
  }

  async checkLoginStatus(headers) {
    debug('================================= APIMLAuth.isLoggedIn');

    const res = await this.httpRequest.request({
      url: '/zosmf/api/v1/restfiles/ds?dslevel=SYS1.PARMLIB*',
      headers: {
        ...headers,
        'X-CSRF-ZOSMF-HEADER': '*',
      },
    });

    return res.status;
  }

}

class ZluxAuth {

  constructor(httpRequest) {
    this.httpRequest = httpRequest;
  }

  _validateAuthResponse(res) {
    // Validate the response at least basically
    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.headers).to.be.an('object');
    expect(res.headers).to.have.property('set-cookie');
    expect(res.data).to.have.property('categories');
    expect(res.data.categories).to.have.property('apiml');
    expect(res.data.categories.apiml).to.have.property('success');
    expect(res.data.categories.apiml.success).to.be.true;
  }

  _extractAuthToken(res) {
    const authCookie = this.httpRequest.findCookieInResponse(res, APIML_AUTH_COOKIE);  
    // Example:
    // apimlAuthenticationToken=eyJ????.eyJ??????.dZ?????; Comment=API Mediation Layer security token; Path=/; SameSite=Strict; HttpOnly; Secure;
    const token = authCookie.split(';')[0].split('=')[1];
    if (!token) {
      throw new Error('The authentication was unsuccessful, failed to find authentication token.');
    }

    return token;
  }

  async login(username, password) {
    debug('================================= ZluxAuth.login');

    if (!username) {
      expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
      username = process.env.SSH_USER;
    }
    if (!password) {
      expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
      password = process.env.SSH_PASSWD;
    }

    const res = await this.httpRequest.request({
      url: '/auth',
      method: 'post',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      data: {
        username,
        password,
      },
    });

    this._validateAuthResponse(res);

    return this._extractAuthToken(res);
  }

}

module.exports = {
  deflate,
  uuid,
  HTTP_STATUS,
  HTTPRequest,
  APIMLAuth,
  ZluxAuth,
};
