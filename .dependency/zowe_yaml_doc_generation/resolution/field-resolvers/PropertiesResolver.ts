import IMegaSchemaResolver from "../IMegaSchemaResolver";
import FieldResolver from "./FieldResolver";

export default class PropertiesResolver extends FieldResolver<any> { // TODO - any?
    public constructor(private megaSchemaResolver: IMegaSchemaResolver) {
        super('properties');
    }

    protected override internalResolve(rootProperties: any[]) {
        const resolvedProperties: { [k: string]: any } = {};

        // 1) look for keys within properties object that have the same name between schemas and collect like { keyName: [val1, val2]}
        const collectedProperties: { [k: string]: any[] } = {};
        for (const rootProperty of rootProperties) {
            for (const [propName, propObj] of Object.entries(rootProperty)) {
                if (!collectedProperties[propName]) {
                    collectedProperties[propName] = [];
                }
                collectedProperties[propName].push(propObj);
            }
        }

        // 2) run megaSchemaResolver.resolve on the [val1, val2] array, which recursively calls all field resolvers
        for (const [propName, propsArr] of Object.entries(collectedProperties)) {
            if (propsArr.length > 1) {
                try {
                    resolvedProperties[propName] = this.megaSchemaResolver.resolveField(propName, propsArr);
                } catch (e) {
                    // not a field to be resolved, so it is a jsonschema array
                    resolvedProperties[propName] = this.megaSchemaResolver.resolve(propsArr);
                }
            } else if (propsArr.length === 1) {
                resolvedProperties[propName] = propsArr[0];
            }
        }

        // 3) pops up the recursive stack, return the result
        return resolvedProperties;
    }
};
