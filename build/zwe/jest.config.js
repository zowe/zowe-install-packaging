module.exports = {
  globals: {
    'ts-jest': {
      tsconfig: 'tsconfig.dev.json'
    }
  },
  roots: [
    './',
    '../../tests/zwe/'
  ],
  transform: {'^.+\\.ts?$': 'ts-jest'},
  testEnvironment: 'node',
  testRegex: '.*\\.(test|spec)?\\.(ts|tsx)$',
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json', 'node', 'd.ts']
};