const fs = require('fs');
const path = require('path');
const title = require('./title-section');
const description = require('./description-section');
const valueConstraints = require('./constraints-section');
const { ROOT_NAME, FILE_EXT, SUB_SECTION_HEADER, SEPARATOR } = require('./md-constants');
const { getSchemaFileName, getRelativePathForChild } = require('./util');

const GENERATED_DOCS_DIR = path.join(__dirname, '../generated');

function writeMdFiles(schema, schemaKey, parentNode = { schema: {}, metadata: {} }, isPatternProp = false) {
    const { metadata, mdContent } = generateDocumentationForNode(schema, schemaKey, parentNode, isPatternProp);
    const dirToWriteFile = `${GENERATED_DOCS_DIR}/${metadata.directory}`;
    if (!fs.existsSync(dirToWriteFile)) {
        fs.mkdirSync(dirToWriteFile, { recursive: true });
    }
    fs.writeFileSync(`${dirToWriteFile}/${metadata.fileName}${FILE_EXT}`, mdContent);

    if (schema.properties) {
        for (const [childSchemaKey, childSchema] of Object.entries(schema.properties)) {
            if (hasNested(childSchema)) {
                writeMdFiles(childSchema, childSchemaKey, { schema, metadata }, false);
            }
        }
    }

    if (schema.patternProperties) {
        for (const [childSchemaKey, childSchema] of Object.entries(schema.patternProperties)) {
            if (hasNested(childSchema)) {
                writeMdFiles(childSchema, childSchemaKey, { schema, metadata }, true);
            }
        }
    }
}

function generateDocumentationForNode(curSchema, curSchemaKey, parentNode, isPatternProp, headingPrefix = '') {
    const subSectionPrefix = headingPrefix + SUB_SECTION_HEADER;
    const metadata = assembleSchemaMetadata(curSchema, curSchemaKey, parentNode.metadata, isPatternProp);
    const curSchemaNode = { schema: curSchema, metadata };

    let mdContent = title.generateMdContent(curSchemaNode, headingPrefix) + description.generateMdContent(curSchemaNode, subSectionPrefix);

    let nestedChildBulletPoints = '';
    let embeddedChildBulletPoints = '';
    let aggregatedChildMdContent = '';
    if (hasNested(curSchema)) {

        if (curSchema.properties) {
            for (const [childSchemaKey, childSchema] of Object.entries(curSchema.properties)) {
                if (hasNested(childSchema)) {
                    nestedChildBulletPoints += `* [${childSchemaKey}](./${getRelativePathForChild(childSchema, childSchemaKey, metadata.fileName, false)})\n`;
                } else {
                    const { metadata: childMetadata, mdContent: childMdContent } = generateDocumentationForNode(childSchema, childSchemaKey, curSchemaNode, false, headingPrefix + '##');
                    embeddedChildBulletPoints += `* ${childMetadata.anchor}\n`
                    aggregatedChildMdContent += childMdContent;
                }
            }
        }
        if (curSchema.patternProperties) {
            for (const [childSchemaKey, childSchema] of Object.entries(curSchema.patternProperties)) {
                if (hasNested(childSchema)) {
                    nestedChildBulletPoints += `* [patternProperty](./${getRelativePathForChild(childSchema, childSchemaKey, metadata.fileName, true)})\n`;
                } else {
                    const { metadata: childMetadata, mdContent: childMdContent } = generateDocumentationForNode(childSchema, childSchemaKey, curSchemaNode, false, headingPrefix + '##');
                    embeddedChildBulletPoints += `* ${childMetadata.anchor}\n`
                    aggregatedChildMdContent += childMdContent;
                }
            }
        }
    }

    // SECTION LEFT OVER BECAUSE NOT MOVED TO value-constraints.js
    // TODO maybe create files before generating md content?
    if (curSchema.oneOf) {
        for (let i = 0; i < curSchema.oneOf.length; i++) {
            const childSchema = curSchema.oneOf[i];
            const childSchemaKey = childSchema.title ?? `${curSchemaKey}-oneOf-${i}`; // TODO fix title
            writeMdFiles(childSchema, childSchemaKey, { schema: curSchema, metadata }, false); // TODO this in value constraints? Or somewhere else?
        }
    }

    if (curSchema.allOf) {
        for (let i = 0; i < curSchema.allOf.length; i++) {
            const childSchema = curSchema.allOf[i];
            const childSchemaKey = childSchema.title ?? `${curSchemaKey}-oneOf-${i}`;
            writeMdFiles(childSchema, childSchemaKey, { schema: curSchema, metadata }, false); // TODO this in value constraints? Or somewhere else?
        }
    }

    // if only an if block then ignore as it has no effect
    // TODO this creates a file for each if/then/else - lots of files
    if (curSchema.if && (curSchema.else || curSchema.then)) {
        const ifSchema = curSchema.if;
        const thenSchema = curSchema.then;
        const elseSchema = curSchema.else;

        const ifSchemaKey = ifSchema.title ?? `${curSchemaKey}-if`;
        writeMdFiles(ifSchema, ifSchemaKey, curSchemaNode, false); // TODO this in value constraints? Or somewhere else?

        if (thenSchema) {
            const thenSchemaKey = thenSchema.title ?? `${curSchemaKey}-then`;
            writeMdFiles(thenSchema, thenSchemaKey, curSchemaNode, false); // TODO this in value constraints? Or somewhere else?
        }

        if (elseSchema) {
            const elseSchemaKey = elseSchema.title ?? `${curSchemaKey}-else`;
            writeMdFiles(elseSchema, elseSchemaKey, curSchemaNode, false); // TODO this in value constraints? Or somewhere else?
        }
    }
    // END OF LEFT OVER BECAUSE NOT MOVED TO value-constraints.js

    if (additionalPropertiesAllowed(curSchema)) {
        mdContent += `Additional properties are allowed.${SEPARATOR}`; // TODO move to value-constraints?
    }

    mdContent += valueConstraints.generateMdContent(curSchemaNode, subSectionPrefix);

    // TODO move to new file
    if (aggregatedChildMdContent || nestedChildBulletPoints || embeddedChildBulletPoints) {
        mdContent += `${subSectionPrefix}Child properties${SEPARATOR}`;

        if (nestedChildBulletPoints) {
            mdContent += `#${subSectionPrefix}Nested configuration blocks${SEPARATOR}${nestedChildBulletPoints}${SEPARATOR}`;
        }

        if (embeddedChildBulletPoints) {
            mdContent += `#${subSectionPrefix}Configuration properties${SEPARATOR}${embeddedChildBulletPoints}${SEPARATOR}`;
        }

        if (aggregatedChildMdContent) {
            mdContent += aggregatedChildMdContent + SEPARATOR;
        }
    }

    mdContent = mdContent.replace('<', '{'); // TODO shouldn't go here, should go in automation that moves over to docs site repo
    return {
        metadata,
        mdContent
    };
}

// returns true then anchor link within same page to the config, false means link to new md file
function hasNested(childSchema) {
    return childSchema && (childSchema.properties || childSchema.patternProperties || childSchema.oneOf || childSchema.allOf);
}

function additionalPropertiesAllowed(curSchema) {
    // if no child properties then cannot have additional properties, even if additionalProperties is not present
    // need strict equality, not present means additionalProperties=true
    return curSchema.properties && curSchema.additionalProperties !== false;
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

module.exports = {
    writeMdFiles
};

// TODO rewrite in typescript?
// TODO dry with zwe doc gen?
