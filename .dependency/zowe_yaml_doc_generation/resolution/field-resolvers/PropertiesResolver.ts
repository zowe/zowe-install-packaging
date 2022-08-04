import FieldResolver from "./FieldResolver";

export default class PropertiesResolver extends FieldResolver<any> { // TODO
    private static instance: PropertiesResolver | null = null;

    private constructor() {
        super('properties');
    }

    protected override internalResolve(schemas: any) {
        // has to be recursive - each nested properties object is a full schema, so it needs to run through all resolvers
        // TODO
    }

    public static getInstance(): PropertiesResolver {
        if (!this.instance) {
            this.instance = new PropertiesResolver();
        }
        return this.instance;
    }
};
