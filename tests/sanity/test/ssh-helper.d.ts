export function prepareConnection(): any;
export function cleanUpConnection(): void;
export function executeCommand(command: any, context?: {}): Promise<{
    rc: any;
    stdout: any;
    stderr: any;
}>;
export function executeCommandWithNoError(command: any, context?: {}): Promise<any>;
export function testCommand(command: any, context?: {}, expected?: {}, exact_match?: boolean): Promise<void>;
export function getTmpDir(): Promise<any>;
