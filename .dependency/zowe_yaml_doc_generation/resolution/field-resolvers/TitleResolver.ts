import FieldResolver from "./FieldResolver";

export default class TitleResolver extends FieldResolver<string> {
    private static instance: TitleResolver | null = null;

    private constructor() {
        super('title');
    }

    protected override internalResolve(titles: string[]) {
        return titles.reduce((acc: string, cur: string) => {
            if (cur) {
                acc += cur + '\n';
            }
            return acc;
        }, '');
    }

    public static getInstance(): TitleResolver {
        if (!this.instance) {
            this.instance = new TitleResolver();
        }
        return this.instance;
    }
};
