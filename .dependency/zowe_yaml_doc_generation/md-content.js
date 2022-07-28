const rootSchema = require('./temp.json');
const fs = require('fs');
const path = require('path');

const GENERATED_DOCS_DIR = path.join(__dirname, './generated');
const ROOT_NAME = 'zowe.yaml';
const SEPARATOR = '\n\n';

const schemas = rootSchema.allOf?.reduce((collected, s) => {
    if (s.properties) {
        collected.push({ title: s.title, description: s.description, properties: s.properties });
    }
    return collected;
}, []);

// TODO generalize to all schemas
const schema = schemas[0];

writeMdFiles(schema, ROOT_NAME);

function writeMdFiles(schema, schemaKey, parentNode = { schema: {}, metadata: {} }) {
    const { metadata, mdContent } = generateDocumentationForNode(schema, schemaKey, parentNode);
    const dirToWriteFile = `${GENERATED_DOCS_DIR}/${metadata.directory}`;
    if (!fs.existsSync(dirToWriteFile)) {
        fs.mkdirSync(dirToWriteFile, { recursive: true });
    }
    fs.writeFileSync(`${dirToWriteFile}/${metadata.fileName}.md`, mdContent);

    if (schema.properties) { // TODO patternProperties??
        for (const [prop, schemaForProp] of Object.entries(schema.properties)) {
            writeMdFiles(schemaForProp, prop, { schema, metadata });
        }
    }
}

function generateDocumentationForNode(curSchema, curSchemaKey, parentNode) {
    console.log(curSchemaKey);
    console.log(curSchema);
    console.log('~~~~~~~~~~~~~~')
    console.log(parentNode);
    console.log('-----------------')
    const metadata = assembleSchemaMetadata(curSchema, curSchemaKey, parentNode.metadata);

    // TODO improve title, consider if title exists then what to do with key
    // TODO could follow cli and have heading be the command (no link, join with dots), then in description section is title/description/comment
    let mdContent = `# ${curSchema.title || curSchemaKey}${SEPARATOR}${metadata.linkYamlKey}${SEPARATOR}${curSchema.description || ''}${SEPARATOR}`;

    // TODO better description section? What to do if no description section?

    // TODO examples section?

    // TODO value requirements section?

    // TODO additional properties

    if (curSchema.properties) {
        // TODO link to children props
    }

    // TODO messes with the links
    mdContent = mdContent.replace('<', '{').replace('>', '}'); // TODO shouldn't go here, should go in automation that moves over to docs site repo
    return {
        metadata,
        mdContent
    };
}

function assembleSchemaMetadata(curSchema, curSchemaKey, parentSchemaMetadata) {
    const fileName = parentSchemaMetadata.fileName && parentSchemaMetadata.fileName !== ROOT_NAME ? `${parentSchemaMetadata.fileName}.${curSchemaKey}` : curSchemaKey;
    const link = `[${curSchemaKey}](./${fileName}.md)`;
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
        link,
        linkKeyElements,
        directory,
        linkYamlKey
    }
}

// TODO rewrite in typescript?
