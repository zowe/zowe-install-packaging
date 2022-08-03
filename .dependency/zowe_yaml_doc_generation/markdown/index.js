const { ROOT_NAME } = require('./md-constants');
const { writeMdFiles } = require('./md-content');

function generateDocumentation(schema, rootName = ROOT_NAME) {
    writeMdFiles(schema, rootName);
}

module.exports = {
    generateDocumentation
};
