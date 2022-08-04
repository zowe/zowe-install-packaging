import FieldResolver from "./FieldResolver";

export default class AdditionalPropertiesResolver extends FieldResolver<boolean> {
    private static instance: AdditionalPropertiesResolver | null = null;

    private constructor() {
        super('additionalProperties');
    }

    protected override internalResolve(additionalPropertiesValues: boolean[]) {
        // if one does not allow additional properties, then result is no further properties are allowed
        return !additionalPropertiesValues.find(ap => !ap);
    }

    public static getInstance(): FieldResolver<boolean> {
        if (!this.instance) {
            this.instance = new AdditionalPropertiesResolver();
        }
        return this.instance;
    }
};
