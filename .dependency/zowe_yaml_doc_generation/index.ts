import { generateZoweYamlMdDocs } from './documentation';
import { Schema } from './documentation/types';

const rootSchema = require('./resolved.json');

const schemas = rootSchema.allOf?.reduce((collected: Schema[], schema: Schema) => {
    if (schema.properties) {
        collected.push({ title: schema.title, description: schema.description, properties: schema.properties });
    }
    return collected;
}, []);

// TODO resolve full yaml schema and then use it here
const schema = schemas[0];

generateZoweYamlMdDocs(schema);
