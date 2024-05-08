/**
 * Sleep for certain time
 * @param {Integer} ms
 */
export declare function sleep(ms: number): Promise<void>;
/**
 * Check if there are any mandatory environment variable is missing.
 *
 * @param {Array} vars     list of env variable names
 */
export declare function checkMandatoryEnvironmentVariables(vars: string[]): void;
/**
 * Generate MD5 hash of a variable
 *
 * @param {Any} obj        any object
 */
export declare function calculateHash(obj: unknown): string;
