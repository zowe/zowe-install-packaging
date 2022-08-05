import { JSONSchema } from "json-schema-ref-parser";
import ResolvedSchema from "./ResolvedSchema";

export default interface IMegaSchemaResolver {
    resolve(dereferencedSchemas: JSONSchema[]): ResolvedSchema;
};
