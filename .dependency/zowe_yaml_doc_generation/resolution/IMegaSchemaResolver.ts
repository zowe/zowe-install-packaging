import { JSONSchema } from "json-schema-ref-parser";
import ResolvedSchema from "./types/ResolvedSchema";

export default interface IMegaSchemaResolver {
    resolve(dereferencedSchemas: JSONSchema[]): ResolvedSchema;

    resolveField(field: string, values: any[]): any;
};
