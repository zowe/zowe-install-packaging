const { FILE_EXT } = require('./md-constants');

function getRelativePathForChild(childSchema, childSchemaKey, curSchemaFileName, isPatternPropFile) {
    const childSchemaFileName = getSchemaFileName(childSchemaKey, curSchemaFileName, isPatternPropFile);
    if (childSchema.properties) {
        // child file name twice, once for directory name once for file name
        return `${childSchemaFileName}/${childSchemaFileName}${FILE_EXT}`;
    }
    return childSchemaFileName + FILE_EXT;
}

function getSchemaFileName(schemaKey, parentFileName, isPatternPropFile) {
    if (isPatternPropFile) {
        // regex, use special file name. Must have a parent
        return `${parentFileName}.patternProperty`;
    }
    // not regex, use normal file name procedure
    return schemaKey;
}

module.exports = {
    getRelativePathForChild,
    getSchemaFileName
}
