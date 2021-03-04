const https = require('https');

const args = process.argv.slice(2)

const host=args[0];
const port=args[1];
const path=args[2];

const options = {
  hostname: host,
  port: port,
  path: path,
  method: 'GET',
  rejectUnauthorized: false,
};

const req = https.request(options, (res) => {
    res.on('data', function (chunk) {
        console.log(`${chunk}`);
    });
}).on("error", (err) => {
  console.log("Error: " + err.message);
});
req.end();