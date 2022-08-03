const { SEPARATOR } = require('./md-constants');

function generateMdContent(curSchemaNode, subSectionPrefix) {
    const { schema, metadata } = curSchemaNode;

    let mdContent = `${subSectionPrefix}Description${SEPARATOR}`;

    if (metadata.isPatternProperty) {
        mdContent += `Properties matching regex: ${SEPARATOR}`; // TODO add actual regex
    }

    mdContent += `\t${metadata.yamlKey}${SEPARATOR}${schema.description || ''}${SEPARATOR}`;

    if (schema.default !== null && schema.default !== undefined) {
        mdContent += `**Default value:** \`${schema.default}\`${SEPARATOR}`;
    }

    if (schema.examples) {
        mdContent += `#${subSectionPrefix}Example values${SEPARATOR}* \`${schema.examples.join('`\n* `')}\`${SEPARATOR}`;
    }

    return mdContent;
}

module.exports = {
    generateMdContent
};
