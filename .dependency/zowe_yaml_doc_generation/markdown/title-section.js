const { SEPARATOR } = require('./md-constants');

function generateMdContent(curSchemaNode, headingPrefix) {
    const { metadata } = curSchemaNode;

    const isEmbeddedChild = headingPrefix !== '';

    let mdContent = `${headingPrefix}# ${metadata.title}${SEPARATOR}`;

    if (isEmbeddedChild) {
        mdContent += `${metadata.anchorKey}${SEPARATOR}`;
    } else {
        mdContent += `${metadata.linkYamlKey}${SEPARATOR}`;
    }

    return mdContent;
}

module.exports = {
    generateMdContent
};
