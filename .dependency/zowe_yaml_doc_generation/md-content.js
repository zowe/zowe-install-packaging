const rootSchema = require('./temp.json');
const fs = require('fs');
const path = require('path');
const valueConstraints = require('./valueConstraints');

const GENERATED_DOCS_DIR = path.join(__dirname, './generated');
const FILE_EXT = '.md';
const ROOT_NAME = 'zowe.yaml';
const SUB_SECTION_HEADER = '## ';
const SEPARATOR = '\n\n';

const schemas = rootSchema.allOf?.reduce((collected, s) => {
    if (s.properties) {
        collected.push({ title: s.title, description: s.description, properties: s.properties });
    }
    return collected;
}, []);

// TODO resolve full yaml schema and then use it here
const schema = schemas[0];

writeMdFiles(schema, ROOT_NAME);

function writeMdFiles(schema, schemaKey, parentNode = { schema: {}, metadata: {} }, isPatternProp = false) {
    const { metadata, mdContent } = generateDocumentationForNode(schema, schemaKey, parentNode, isPatternProp);
    const dirToWriteFile = `${GENERATED_DOCS_DIR}/${metadata.directory}`;
    if (!fs.existsSync(dirToWriteFile)) {
        fs.mkdirSync(dirToWriteFile, { recursive: true });
    }
    fs.writeFileSync(`${dirToWriteFile}/${metadata.fileName}${FILE_EXT}`, mdContent);

    if (schema.properties) {
        for (const [childSchemaKey, childSchema] of Object.entries(schema.properties)) {
            if (childSchema.properties || childSchema.patternProperties) {
                writeMdFiles(childSchema, childSchemaKey, { schema, metadata }, false);
            }
        }
    }

    if (schema.patternProperties) {
        for (const [childSchemaKey, childSchema] of Object.entries(schema.patternProperties)) {
            if (childSchema.properties || childSchema.patternProperties) {
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
    if (constraints.length || curSchema.required?.length) {
        mdContent += `${subSectionPrefix}Value constraints${SEPARATOR}`;
        if (constraints.length) {
            mdContent += `* ${constraints.join('\n* ')}\n`;
        }
        if (curSchema.required?.length) {
            mdContent += `* Must have child property \`${curSchema.required.join('` defined\n* Must have child property `')}\` defined\n`;
        }
        mdContent += SEPARATOR;
    }

    if (curSchema.examples) {
        mdContent += `${subSectionPrefix}Example values${SEPARATOR}* \`${curSchema.examples.join('`\n* `')}\`${SEPARATOR}`;
    }

    if (curSchema.properties || curSchema.patternProperties) {
        mdContent += `${subSectionPrefix}Child properties${SEPARATOR}`;

        let nestedChildBulletPoints = '';
        let embeddedChildBulletPoints = '';
        let aggregatedChildMdContent = '';
        if (curSchema.properties) {
            for (const [childSchemaKey, childSchema] of Object.entries(curSchema.properties)) {
                if (childSchema.properties || childSchema.patternProperties) {
                    if (childSchema.properties) {
                        nestedChildBulletPoints += `* [${childSchemaKey}](./${getRelativePathForChild(childSchema, childSchemaKey, metadata.fileName, false)})\n`;
                    }
                    if (childSchema.patternProperties) {
                        nestedChildBulletPoints += `* [${childSchemaKey}](./${getRelativePathForChild(childSchema, childSchemaKey, metadata.fileName, false)})\n`;
                    }
                } else {
                    const { metadata: childMetadata, mdContent: childMdContent } = generateDocumentationForNode(childSchema, childSchemaKey, { schema: curSchema, metadata }, false, headingPrefix + '#');
                    embeddedChildBulletPoints += `* ${childMetadata.anchor}\n`
                    aggregatedChildMdContent += childMdContent;
                }
            }
        }
        if (curSchema.patternProperties) {
            for (const [childSchemaKey, childSchema] of Object.entries(curSchema.patternProperties)) {
                if (childSchema.properties || childSchema.patternProperties) {
                    if (childSchema.properties) {
                        nestedChildBulletPoints += `* [patternProperty](./${getRelativePathForChild(childSchema, childSchemaKey, metadata.fileName, true)})\n`;
                    }
                    if (childSchema.patternProperties) {
                        nestedChildBulletPoints += `* [patternProperty](./${getRelativePathForChild(childSchema, childSchemaKey, metadata.fileName, true)})\n`;
                    }
                } else {
                    const { metadata: childMetadata, mdContent: childMdContent } = generateDocumentationForNode(childSchema, childSchemaKey, { schema: curSchema, metadata }, false, headingPrefix + '#');
                    embeddedChildBulletPoints += `* ${childMetadata.anchor}\n`
                    aggregatedChildMdContent += childMdContent;
                }
            }
        }

        if (additionalPropertiesAllowed(curSchema)) {
            mdContent += `Additional properties are allowed.${SEPARATOR}`;
        }

        if (nestedChildBulletPoints) {
            mdContent += `#${subSectionPrefix}Nested configuration blocks${SEPARATOR}${nestedChildBulletPoints}${SEPARATOR}`;
        }

        if (embeddedChildBulletPoints) {
            mdContent += `#${subSectionPrefix}Configuration properties${SEPARATOR}${embeddedChildBulletPoints}${SEPARATOR}`;
        }

        mdContent += SEPARATOR;

        if (aggregatedChildMdContent) {
            mdContent += aggregatedChildMdContent;
        }

        mdContent += SEPARATOR;
    }

    mdContent = mdContent.replace('<', '{'); // TODO shouldn't go here, should go in automation that moves over to docs site repo
    return {
        metadata,
        mdContent
    };
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
    const anchor = `[${title}](#${yamlKey})`.replace(/\./g, '').toLowerCase(); // no dots and is lower case in md anchor
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

    const linkYamlKey = linkKeyElements.join(' > '); // TODO ideally use '>' but makes docs site sanitation harder

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
