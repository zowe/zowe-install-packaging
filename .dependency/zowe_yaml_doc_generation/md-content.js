const fs = require('fs');
const path = require('path');
const valueConstraints = require('./valueConstraints');

const GENERATED_DOCS_DIR = path.join(__dirname, './generated');
const FILE_EXT = '.md';
const ROOT_NAME = 'zowe.yaml';
const SUB_SECTION_HEADER = '## ';
const SEPARATOR = '\n\n';

module.exports.generateDocumentation = function (schema, rootName = ROOT_NAME) {
    writeMdFiles(schema, rootName);
}

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
    // TODO deal with logic in schema like allOf, oneOf, if/then/else, etc

    const isEmbeddedChild = headingPrefix !== '';

    let mdContent = `${headingPrefix}# ${metadata.title}${SEPARATOR}`;
    if (isEmbeddedChild) {
        mdContent += `${metadata.anchorKey}${SEPARATOR}`;
    } else {
        mdContent += `${metadata.linkYamlKey}${SEPARATOR}`;
    }

    mdContent += `${subSectionPrefix}Description${SEPARATOR}`;

    if (isPatternProp) {
        mdContent += `Properties matching regex: ${SEPARATOR}`;
    }

    mdContent += `\t${metadata.yamlKey}${SEPARATOR}${curSchema.description || ''}${SEPARATOR}`;

    if (curSchema.default !== null && curSchema.default !== undefined) {
        mdContent += `**Default value:** \`${curSchema.default}\`${SEPARATOR}`;
    }

    const constraints = [];
    for (const [propKey, constraint] of Object.entries(curSchema)) {
        for (const { key, mdGenerator } of valueConstraints) {
            if (key === propKey) {
                constraints.push(mdGenerator(constraint));
            }
        }
    }

    if (curSchema.examples) {
        mdContent += `${subSectionPrefix}Example values${SEPARATOR}* \`${curSchema.examples.join('`\n* `')}\`${SEPARATOR}`;
    }

    const parentSchemaMetadata = { schema: curSchema, metadata };
    
    let nestedChildBulletPoints = '';
    let embeddedChildBulletPoints = '';
    let aggregatedChildMdContent = '';
    if (hasNested(curSchema)) {

        if (curSchema.properties) {
            for (const [childSchemaKey, childSchema] of Object.entries(curSchema.properties)) {
                if (hasNested(childSchema)) {
                    nestedChildBulletPoints += `* [${childSchemaKey}](./${getRelativePathForChild(childSchema, childSchemaKey, metadata.fileName, false)})\n`;
                } else {
                    const { metadata: childMetadata, mdContent: childMdContent } = generateDocumentationForNode(childSchema, childSchemaKey, parentSchemaMetadata, false, headingPrefix + '##');
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
                    const { metadata: childMetadata, mdContent: childMdContent } = generateDocumentationForNode(childSchema, childSchemaKey, parentSchemaMetadata, false, headingPrefix + '##');
                    embeddedChildBulletPoints += `* ${childMetadata.anchor}\n`
                    aggregatedChildMdContent += childMdContent;
                }
            }
        }
    }

    const oneOfBulletPointsList = [];
    if (curSchema.oneOf) {
        for (let i = 0; i < curSchema.oneOf.length; i++) {
            const childSchema = curSchema.oneOf[i];
            const childSchemaKey = childSchema.title ?? `${curSchemaKey}-oneOf-${i}`;
            writeMdFiles(childSchema, childSchemaKey, { schema: curSchema, metadata }, false);
            oneOfBulletPointsList.push(`* [${childSchemaKey}](./${getRelativePathForChild(childSchema, childSchemaKey, metadata.fileName, false)})`);
        }
    }

    const allOfBulletPointsList = [];
    if (curSchema.allOf) {
        for (let i = 0; i < curSchema.allOf.length; i++) {
            const childSchema = curSchema.allOf[i];
            const childSchemaKey = childSchema.title ?? `${curSchemaKey}-allOf-${i}`;
            writeMdFiles(childSchema, childSchemaKey, { schema: curSchema, metadata }, false);
            allOfBulletPointsList.push(`* [${childSchemaKey}](./${getRelativePathForChild(childSchema, childSchemaKey, metadata.fileName, false)})`);
        }
    }

    const ifLogicBulletPoints = [];
    // if only an if block then ignore as it has no effect
    // TODO this creates a file for each if/then/else - lots of files
    if (curSchema.if && (curSchema.else || curSchema.then)) {
        const ifSchema = curSchema.if;
        const thenSchema = curSchema.then;
        const elseSchema = curSchema.else;

        const ifSchemaKey = ifSchema.title ?? `${curSchemaKey}-if`;
        writeMdFiles(ifSchema, ifSchemaKey, parentSchemaMetadata, false);
        const ifSchemaRelativeFilePath = './' + getRelativePathForChild(ifSchema, ifSchemaKey, metadata.fileName, false);

        if (thenSchema) {
            const thenSchemaKey = thenSchema.title ?? `${curSchemaKey}-then`;
            writeMdFiles(thenSchema, thenSchemaKey, parentSchemaMetadata, false);

            const thenSchemaRelativeFilePath = './' + getRelativePathForChild(thenSchema, thenSchemaKey, metadata.fileName, false);
            ifLogicBulletPoints.push(`* If the [${ifSchemaKey}](${ifSchemaRelativeFilePath}) schema is satisfied,` +
                ` then the [${thenSchemaKey}](${thenSchemaRelativeFilePath}) must also be satisfied`);
        }

        if (elseSchema) {
            const elseSchemaKey = elseSchema.title ?? `${curSchemaKey}-else`;
            writeMdFiles(elseSchema, elseSchemaKey, parentSchemaMetadata, false);

            const elseSchemaRelativeFilePath = './' + getRelativePathForChild(elseSchema, elseSchemaKey, metadata.fileName, false);
            ifLogicBulletPoints.push(`* If the [${ifSchemaKey}](${ifSchemaRelativeFilePath}) schema is **NOT** satisfied,` +
                ` then the [${elseSchemaKey}](${elseSchemaRelativeFilePath}) must be satisfied`);
        }
    }

    if (additionalPropertiesAllowed(curSchema)) {
        mdContent += `Additional properties are allowed.${SEPARATOR}`;
    }

    if (constraints.length || curSchema.required?.length || oneOfBulletPointsList.length || allOfBulletPointsList.length || ifLogicBulletPoints.length) {
        mdContent += `${subSectionPrefix}Value constraints${SEPARATOR}`;
        if (constraints.length) {
            mdContent += `* ${constraints.join('\n* ')}\n`;
        }

        if (curSchema.required?.length) {
            mdContent += `* Must have child property \`${curSchema.required.join('` defined\n* Must have child property `')}\` defined\n`;
        }

        if (oneOfBulletPointsList.length) {
            mdContent += `* One of the following specifications must be satisfied:\n\t${oneOfBulletPointsList.join('\n\t')}\n`;
        }

        if (allOfBulletPointsList.length) {
            mdContent += `* All of the following specifications must be satisfied:\n\t${allOfBulletPointsList.join('\n\t')}\n`;
        }

        if (ifLogicBulletPoints.length) {
            mdContent += `* The following if-then-else schema logic must be satisfied:\n\t${ifLogicBulletPoints.join('\n\t')}`
        }

        mdContent += SEPARATOR;
    }

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

function getRelativePathForChild(childSchema, childSchemaKey, curSchemaFileName, isPatternPropFile) {
    const childSchemaFileName = getSchemaFileName(childSchemaKey, curSchemaFileName, isPatternPropFile);
    if (childSchema.properties) {
        // child file name twice, once for directory name once for file name
        return `${childSchemaFileName}/${childSchemaFileName}${FILE_EXT}`;
    }
    return childSchemaFileName + FILE_EXT;
}

function assembleSchemaMetadata(curSchema, curSchemaKey, parentSchemaMetadata, isPatternPropFile) {
    const fileName = getSchemaFileName(curSchemaKey, parentSchemaMetadata.fileName, isPatternPropFile);
    const title = isPatternPropFile ? 'patternProperty' : curSchemaKey;
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
        linkYamlKey
    }
}

function getSchemaFileName(schemaKey, parentFileName, isPatternPropFile) {
    if (isPatternPropFile) {
        // regex, use special file name. Must have a parent
        return `${parentFileName}.patternProperty`;
    }
    // not regex, use normal file name procedure
    return schemaKey;
}

// TODO rewrite in typescript?
// TODO dry with zwe doc gen?
