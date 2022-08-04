import { ROOT_NAME } from './md-constants';
import JsonSchemaDocumentation from './JsonSchemaDocumentation';
import { Schema } from './types';

const jsonSchemaDocumentation = new JsonSchemaDocumentation();

export function generateZoweYamlMdDocs(schema: Schema, rootName = ROOT_NAME) {
    jsonSchemaDocumentation.writeMdFiles(schema, rootName);
}

