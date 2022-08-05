import { JSONSchema } from "json-schema-ref-parser";
import { FieldResolver, DescriptionResolver, TitleResolver, AdditionalPropertiesResolver, TypeResolver, RequiredResolver, PropertiesResolver } from "./field-resolvers";
import IMegaSchemaResolver from "./IMegaSchemaResolver";
import ResolvedSchema from "./types/ResolvedSchema";

// resolve everything by smashing together all unique properties
// identify properties that we care about - e.g. description, title, properties, patternProperties, etc
// and then create a merging solution for each - e.g. description and title join with '\n', properties is smash together, etc.
export default class MultiFieldResolver implements IMegaSchemaResolver {
    private resolvers: FieldResolver<any>[];

    public constructor() {
        this.resolvers = [
            new DescriptionResolver(),
            new TitleResolver(),
            new AdditionalPropertiesResolver(),
            new TypeResolver(),
            new RequiredResolver(),
            new PropertiesResolver(this)
        ];
    }

    public resolve(dereferencedSchemas: JSONSchema[]): ResolvedSchema {
        const resolvedSchema: { [k: string]: any } = {};
        for (const resolver of this.resolvers) {
            resolvedSchema[resolver.field] = resolver.resolve(dereferencedSchemas);
        }

        return resolvedSchema as ResolvedSchema; // TODO no type coercion
    }

    public resolveField(field: string, values: any[]): any {
        const resolver = this.resolvers.find((r: FieldResolver<any>) => r.field === field);
        if (!resolver) {
            throw new Error(`No resolver for field '${field}' found`);
        }

        return resolver.resolveField(values);
    }
};
