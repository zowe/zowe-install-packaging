const zlib = require('zlib');


const deflate = (dataStream) => new Promise((resolve, reject) => {
  try {
    let gunzip = zlib.createGunzip();            
    dataStream.pipe(gunzip);
    gunzip.on('data', function(data) {
      resolve(JSON.parse(data.toString()));
    });
    gunzip.on('error', function(err) {
      reject(err);
    });
  } catch(err) {
    reject(err);
  }
});

module.exports = {
  deflate
};