import path from 'path';
import SchemaResolver from './resolution/SchemaResolver';

const RESOLVED_SCHEMA_FILE_PATH = path.join(__dirname, './resolved.json');

const schemaResolver = new SchemaResolver(RESOLVED_SCHEMA_FILE_PATH);
schemaResolver.resolveMegaSchema();
