import { SchemasById, ResolvedSchema } from "./types";

export function getSchemaById(schemaId: string, schemas: SchemasById): ResolvedSchema {
    for (const [id, schema] of Object.entries(schemas)) {
        if (id.endsWith(schemaId)) {
            return schema;
        }
    }
    throw new Error(`Could not find schema with id '${schemaId}'`);
}
