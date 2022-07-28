const rootSchema = require('./temp.json');
const fs = require('fs');
const path = require('path');

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

// TODO print full zowe.yaml schema from config manager
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
        for (const [prop, schemaForProp] of Object.entries(schema.properties)) {
            writeMdFiles(schemaForProp, prop, { schema, metadata }, false);
        }
    }

    if (schema.patternProperties) {
        for (const [prop, schemaForProp] of Object.entries(schema.patternProperties)) {
            writeMdFiles(schemaForProp, prop, { schema, metadata }, true);
        }
    }
}

function generateDocumentationForNode(curSchema, curSchemaKey, parentNode, isPatternProp) {
    console.log(curSchemaKey);
    console.log(curSchema);
    console.log('~~~~~~~~~~~~~~')
    console.log(parentNode);
    console.log('-----------------')
    const metadata = assembleSchemaMetadata(curSchema, curSchemaKey, parentNode.metadata, isPatternProp);
    // TODO deal with logic in schema like allOf, oneOf, if/then/else, etc

    let mdContent = `# ${metadata.yamlKey}${SEPARATOR}${metadata.linkYamlKey}${SEPARATOR}` +
        `${SUB_SECTION_HEADER}Description${SEPARATOR}`;

    if (isPatternProp) {
        mdContent += `Properties matching regex: ${SEPARATOR}`;
    }

    mdContent += `\t${curSchema.title || curSchemaKey}${SEPARATOR}${curSchema.description || ''}${SEPARATOR}`;

    if (curSchema.default !== null && curSchema.default !== undefined) {
        mdContent += `**Default value:** \`${curSchema.default}\`${SEPARATOR}`;
    }

    if (curSchema.examples) {
        mdContent += `${SUB_SECTION_HEADER}Example values${SEPARATOR}* \`${curSchema.examples.join('`\n* `')}\``;
    }

    // TODO value requirements section?
    // type, minLength, maxLength, minValue, etc

    if (curSchema.properties || curSchema.patternProperties) {
        mdContent += `${SUB_SECTION_HEADER}Child properties${SEPARATOR}`;
        if (curSchema.properties) {
            mdContent += `${Object.entries(curSchema.properties)
                .map(([prop, schema]) => `* [${prop}](./${getRelativePathForChild(schema, prop, metadata.fileName, false)})`)
                .join('\n')}`;
        }

        if (curSchema.patternProperties) {
            mdContent += `${Object.entries(curSchema.patternProperties)
                .map(([pattern, schema]) => `* [Additional properties matching the regex '${pattern}'](./${getRelativePathForChild(schema, pattern, metadata.fileName, true)})`)
                .join('\n')}`;
        }

        mdContent += SEPARATOR;

        if (additionalPropertiesAllowed(curSchema)) {
            mdContent += `Additional properties are allowed.${SEPARATOR}`;
        }
    }

    mdContent = mdContent.replace('<', '{').replace('>', '}'); // TODO shouldn't go here, should go in automation that moves over to docs site repo
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
    const yamlKey = parentSchemaMetadata.yamlKey && parentSchemaMetadata.yamlKey !== ROOT_NAME ? `${parentSchemaMetadata.yamlKey}.${curSchemaKey}` : curSchemaKey;
    const link = `[${curSchemaKey}](./${fileName}${FILE_EXT})`;
    const linkKeyElements = parentSchemaMetadata.linkKeyElements && parentSchemaMetadata.fileName !== ROOT_NAME ? [...parentSchemaMetadata.linkKeyElements, link] : [link];

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

    const linkYamlKey = linkKeyElements.join('.'); // TODO ideally use '>' but makes docs site sanitation harder

    return {
        fileName,
        linkKeyElements,
        directory,
        yamlKey,
        linkYamlKey
    }
}

function getSchemaFileName(schemaKey, parentFileName, isPatternPropFile) {
    if (isPatternPropFile) {
        // regex, use special file name. Must have a parent
        return `${parentFileName}.patternProperty`;
    }
    // not regex, use normal file name procedure
    return parentFileName && parentFileName !== ROOT_NAME ? `${parentFileName}.${schemaKey}` : schemaKey;
}

// TODO rewrite in typescript?
// TODO dry with zwe doc gen?
