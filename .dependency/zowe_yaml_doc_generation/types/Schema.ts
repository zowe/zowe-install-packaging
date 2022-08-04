import { type JSONSchema } from "json-schema-typed/draft-2019-09";

type CustomJsonSchemaType = {

}

export type Schema = CustomJsonSchemaType & JSONSchema & JSONSchema.Interface; // interface is used for extending