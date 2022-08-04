/*
Could be used, but have to resolve references to other schemas myself. Would also need
to manually either deal with headings or split into multiple articles, too much nesting makes 
headings too small
*/
// const jsonToMd = require('json-schema-to-markdown');
// const schema = require('./schemas/caching-schema.json');
// const markdown = jsonToMd(schema);
// console.log(markdown);

/*
Ajv can load multiple schemas and validate between them, but won't resolve references.

*/
// const Ajv2019 = require('ajv/dist/2019');
// const ajv = new Ajv2019();
// const zoweYamlSchema = require('./otherschemas/zowe-yaml-schema.json');
// const serverCommonSchema = require('./schemas/server-common.json');
// ajv.addKeyword("$anchor"); // TODO
// ajv.addSchema(zoweYamlSchema);
// ajv.addSchema(serverCommonSchema);
// const s = ajv.getSchema("https://zowe.org/schemas/v2/server-base");
// console.log(s.schema.properties.zowe.properties.setup.properties.dataset.properties.parmlibMembers)
// const validate = ajv.compile(zoweYamlSchema);
// console.log(validate);


/*
I want a fully resolved schema representing Zowe.yaml, this can then be turned into markdown by json-schema-to-markdown.
I can then take that generated markdown and parse it into separate files and folders to make a human searchable tree like zwe.

However, json-schema-to-markdown only keeps the prop name and description, there's no information about valid values, and no
link to the schema - I would like these.
*/

import fs from 'fs';
import path from 'path';
import { default as refParser } from 'json-schema-ref-parser';

// json-schema-ref-parser doesn't have some draft19-09 keywords
type ResolvedSchema = {
    $defs: any;
    $anchor: string;
} & refParser.JSONSchema;

// Read all schemas so that can resolve schema references
const SCHEMAS_DIR = path.join(__dirname, './schemas/');
const RESOLVED_SCHEMA_FILE_PATH = path.join(__dirname, '../resolved.json');

const schemas: { [k: string]: ResolvedSchema } = {};
fs.readdirSync(SCHEMAS_DIR).forEach(file => {
    try {
        // Library cannot resolve references that don't have '/' after '#' and don't explicitly have $defs in path.
        // So while reading the schemas into memory, replace reference paths to ensure they are in the form ...#/$defs/...
        const stringSchema = fs.readFileSync(SCHEMAS_DIR + file, 'utf8');
        const fixedRefPathsStringSchema = stringSchema.replace(/(\$ref.*#)\/?(\$defs)?\/?([^/])/g, '$1/$defs/$3');

        const schema = JSON.parse(fixedRefPathsStringSchema);
        schemas[schema.$id] = schema;
    } catch (e) {
        console.error(`Could not read schema file ${file}: ${e}`);
    }
});

const parser: refParser.ParserOptions = {
    order: 1,
    canParse: ".json",

    parse(file): ResolvedSchema {
        // This is the file being referenced by the schema that is getting dereferenced.
        // Resolver can't handle anchors and some path syntax used (e.g. requires $defs in the path), and can't see the path/anchor so
        // custom resolver can't fix. So, this will take any $defs and put them top level, and
        // make a duplicate object with key for the real name and a key for the anchor

        let parsedSchema: ResolvedSchema = JSON.parse(file.data.toString());
        if (parsedSchema?.$defs) {
            const defs = parsedSchema.$defs;
            const anchoredDefs = Object.entries<ResolvedSchema>(defs).reduce<{ [k: string]: ResolvedSchema }>((obj, [_, defValue]) => {
                if (defValue.$anchor) {
                    obj[defValue.$anchor] = defValue;
                }
                return obj;
            }, {});

            parsedSchema.$defs = { ...defs, ...anchoredDefs };
        }
        return parsedSchema;
    }
}

const resolver: Partial<refParser.ResolverOptions> = {
    order: 1,

    canRead(ref): boolean {
        // TODO can this result be cached? read does the same operation, canRead should always be ran before read
        const schema = getSchemaById(ref.url);
        return schema !== null && schema !== undefined;
    },

    // parser expects a string or buffer to be read from the file
    read(ref): string {
        return JSON.stringify(getSchemaById(ref.url));
    }
}

async function resolvedSchema(schemaId: string) {
    // need to use loaded schemas, not required schema, as the ref paths need to be fixed as done when schemas are loaded
    return await refParser.dereference(getSchemaById(schemaId), { resolve: { file: resolver }, parse: { json: parser } });
}

function getSchemaById(schemaId: string): ResolvedSchema {
    for (const [id, schema] of Object.entries(schemas)) {
        if (id.endsWith(schemaId)) {
            return schema;
        }
    }
    throw new Error(`Could not find schema with id '${schemaId}'`);
}

resolvedSchema('caching-config').then((resolvedSchema) => {
    fs.writeFileSync(RESOLVED_SCHEMA_FILE_PATH, JSON.stringify(resolvedSchema, null, 2));
});
