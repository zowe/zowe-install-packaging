const https = require('https');

const args = process.argv.slice(2)
const zosmfIp=args[0];
const zosmfPort=args[1];

const options = {
  hostname: zosmfIp,
  port: zosmfPort,
  path: '/zosmf/info',
  method: 'GET',
  rejectUnauthorized: false,
  headers: {'X-CSRF-ZOSMF-HEADER': true}
};

const req = https.request(options, (res) => {
  console.log(res.statusCode);
}).on("error", (err) => {
  console.log("Error: " + err.message);
});
req.end();