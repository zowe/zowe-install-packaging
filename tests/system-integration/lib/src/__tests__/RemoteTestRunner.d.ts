import ZoweYamlType from '../ZoweYamlType';
export declare class RemoteTestRunner {
    private session;
    RemoteTestRunner(): void;
    /**
     *
     * @param zoweYaml
     * @param zweCommand
     * @param cwd
     */
    runTest(zoweYaml: ZoweYamlType, zweCommand: string, cwd?: string): Promise<TestOutput>;
}
export type TestOutput = {
    stdout: string;
    rc: number;
};
