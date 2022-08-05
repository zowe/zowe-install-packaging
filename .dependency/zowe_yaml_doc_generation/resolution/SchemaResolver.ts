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
import { ResolvedSchema, SchemasById } from './types';
import MultiFieldResolver from './MultiFieldResolver';
import RefResolver from './parsing/RefResolver';
import SchemaParser from './parsing/SchemaParser';
import { getSchemaById } from './util';

// Read all schemas so that can resolve schema references
const SCHEMAS_DIR = path.join(__dirname, './schemas/');


export default class SchemaResolver {

    private readonly schemas: SchemasById;
    private readonly resolver: RefResolver;
    private readonly parser: SchemaParser = new SchemaParser();

    public constructor(private resolvedSchemaPath: string) {
        this.schemas = {};
        fs.readdirSync(SCHEMAS_DIR).forEach(file => {
            try {
                // Library cannot resolve references that don't have '/' after '#' and don't explicitly have $defs in path.
                // So while reading the schemas into memory, replace reference paths to ensure they are in the form ...#/$defs/...
                const stringSchema = fs.readFileSync(SCHEMAS_DIR + file, 'utf8');
                const fixedRefPathsStringSchema = stringSchema.replace(/(\$ref.*#)\/?(\$defs)?\/?([^/])/g, '$1/$defs/$3');

                const schema = JSON.parse(fixedRefPathsStringSchema);
                this.schemas[schema.$id] = schema;
            } catch (e) {
                console.error(`Could not read schema file ${file}: ${e}`);
            }
        });

        this.resolver = new RefResolver(this.schemas);
    }

    public async resolveMegaSchema() {
        const resolvedSchema = await this.resolveSchema('zowe-components');
        fs.writeFileSync(this.resolvedSchemaPath, JSON.stringify(resolvedSchema, null, 2));
    }



    private async resolveSchema(schemaId: string) {
        // need to use loaded schemas, not required schema, as the ref paths need to be fixed as done when schemas are loaded
        const dereferencedSchema = await refParser.dereference(getSchemaById(schemaId, this.schemas), { resolve: { file: this.resolver }, parse: { json: this.parser } });
        // result is a top level mega schema that has allOf[each,zowe,component,schema] - each of which then have server base, components, etc.


        // flatten by one level by getting the child allOf (I think we can rely on components always having allOf, but good to generalize later)
        // TODO issue with calling reduce so did 'as any[]' - look into fixing this
        dereferencedSchema.allOf = (dereferencedSchema.allOf as any[])
            .reduce((acc: refParser.JSONSchema[], cur: refParser.JSONSchema) => {
                if (cur.allOf) {
                    for (const level2 of cur.allOf as refParser.JSONSchema[]) {
                        // only add if unique
                        // TODO what if there are duplicates with no $id? Will this happen?
                        if (!level2.$id || !acc.find(s => s.$id === level2.$id)) {
                            acc.push(level2);
                        }
                    }
                }
                return acc;
            }, []);

        const megaSchema = new MultiFieldResolver();
        return megaSchema.resolve(dereferencedSchema.allOf as refParser.JSONSchema[]); // know that top level schema has allOf with all schemas in it
    }
}
