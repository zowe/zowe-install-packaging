const fs = require('fs');
const path = require('path');
const title = require('./title-section');
const description = require('./description-section');
const ConstraintsSection = require('./ConstraintsSection');
const ChildConfiguration = require('./ChildConfigurationSection');
const { ROOT_NAME, FILE_EXT, SUB_SECTION_HEADER } = require('./md-constants');
const { getSchemaFileName, hasNestedConfigurationBlock } = require('./util');

const GENERATED_DOCS_DIR = path.join(__dirname, '../generated');

class JsonSchemaDocumentation {

    constructor() {
        this.childConfiguration = new ChildConfiguration(this);
        this.valueConstraints = new ConstraintsSection(this);
    }

    writeMdFiles(schema, schemaKey, parentNode = { schema: {}, metadata: {} }, isPatternProp = false) {
        const { metadata, mdContent } = this.generateDocumentationForNode(schema, schemaKey, parentNode, isPatternProp);
        const dirToWriteFile = `${GENERATED_DOCS_DIR}/${metadata.directory}`;
        if (!fs.existsSync(dirToWriteFile)) {
            fs.mkdirSync(dirToWriteFile, { recursive: true });
        }
        fs.writeFileSync(`${dirToWriteFile}/${metadata.fileName}${FILE_EXT}`, mdContent);

        if (schema.properties) {
            for (const [childSchemaKey, childSchema] of Object.entries(schema.properties)) {
                if (hasNestedConfigurationBlock(childSchema)) {
                    this.writeMdFiles(childSchema, childSchemaKey, { schema, metadata }, false);
                }
            }
        }

        if (schema.patternProperties) {
            for (const [childSchemaKey, childSchema] of Object.entries(schema.patternProperties)) {
                if (hasNestedConfigurationBlock(childSchema)) {
                    this.writeMdFiles(childSchema, childSchemaKey, { schema, metadata }, true);
                }
            }
        }
    }

    generateDocumentationForNode(curSchema, curSchemaKey, parentNode, isPatternProp, headingPrefix = '') {
        const subSectionPrefix = headingPrefix + SUB_SECTION_HEADER;

        const metadata = assembleSchemaMetadata(curSchema, curSchemaKey, parentNode.metadata, isPatternProp);
        const curSchemaNode = { schema: curSchema, metadata };

        const mdContent = title.generateMdContent(curSchemaNode, headingPrefix)
            + description.generateMdContent(curSchemaNode, subSectionPrefix)
            + this.valueConstraints.generateMdContent(curSchemaNode, subSectionPrefix)
            + this.childConfiguration.generateMdContent(curSchemaNode, headingPrefix);

        const cleanedMdContent = mdContent.replace('<', '{'); // TODO shouldn't go here, should go in automation that moves over to docs site repo
        return {
            metadata,
            mdContent: cleanedMdContent
        };
    }
}

function assembleSchemaMetadata(curSchema, curSchemaKey, parentSchemaMetadata, isPatternProperty) {
    const fileName = getSchemaFileName(curSchemaKey, parentSchemaMetadata.fileName, isPatternProperty);
    const title = isPatternProperty ? 'patternProperty' : curSchemaKey;
    const yamlKey = parentSchemaMetadata.yamlKey && parentSchemaMetadata.yamlKey !== ROOT_NAME ? `${parentSchemaMetadata.yamlKey}.${title}` : title;
    const link = `[${title}](./${fileName}${FILE_EXT})`;
    const anchor = `[${title}](#${title.toLowerCase()})`; // md anchor is lower case
    const linkKeyElements = parentSchemaMetadata.linkKeyElements ? [...parentSchemaMetadata.linkKeyElements, link] : [link];

    let relPathToParentLinks = './';
    let directory = parentSchemaMetadata.directory ? parentSchemaMetadata.directory : '.';
    if (curSchema.properties) {
        directory += `/${fileName}`;
        relPathToParentLinks = '../';
    }

    // add '../'to make link to parent keys proper given the directory structure
    for (let elementIndex = 0; elementIndex < linkKeyElements.length - 1; elementIndex++) {
        linkKeyElements[elementIndex] = linkKeyElements[elementIndex].replace(/\(/, '(' + relPathToParentLinks); // path starts after '(', so add '../' after '('
    }

    const linkYamlKey = linkKeyElements.join(' > ');

    // don't use anchor from parents as they may be in a different file, can just link to the file
    const anchorKeyElements = parentSchemaMetadata.linkKeyElements && parentSchemaMetadata.fileName !== ROOT_NAME ? [...parentSchemaMetadata.linkKeyElements, anchor] : [anchor];
    const anchorKey = anchorKeyElements.join(' > ');

    return {
        title,
        fileName,
        linkKeyElements,
        directory,
        yamlKey,
        anchor,
        anchorKey,
        linkYamlKey,
        curSchemaKey,
        isPatternProperty
    }
}

module.exports = JsonSchemaDocumentation;

// TODO rewrite in typescript?
// TODO dry with zwe doc gen?
