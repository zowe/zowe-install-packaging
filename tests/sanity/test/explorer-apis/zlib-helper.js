const _ = require('lodash');
const zlib = require('zlib');
const expect = require('chai').expect;

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

function manualDecompressionRequest(REQ, req, ungzip) {
  let overrideOptions = {
    responseType: 'stream',
    decompress: false
  };

  let addHeader = {
    'Accept-Encoding': 'gzip'
  };

  req = Object.assign({},req,overrideOptions);
  req.headers = Object.assign({},req.headers,addHeader);
  

  let resp;
  return REQ.request(req)
    .then(function(res) {
      expect(res.headers).to.have.property('content-encoding');
      expect(res.headers['content-encoding']).to.equal('gzip');  
      resp = _.pick(res, ['status', 'statusText', 'headers', 'data']);
      if(ungzip) {
        return deflate(res.data);  
      } else {
        return res.data;
      }
    })
    .then((data) => {
      resp.data = data;
      return resp;
    });
}

function handleCompressionRequest(REQ, req, handleOptions) {
  let options =  Object.assign({},{manualDecompress: false, ungzip: true}, handleOptions);
  if(options.manualDecompress) {
    return manualDecompressionRequest(REQ,req, options.ungzip);
  }
  return REQ.request(req);
}

module.exports = {
  deflate,
  handleCompressionRequest
};