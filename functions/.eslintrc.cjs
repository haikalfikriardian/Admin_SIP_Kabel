// functions/.eslintrc.cjs
module.exports = {
  root: true,
  env: { node: true, es2021: true },
  parserOptions: { ecmaVersion: 2021, sourceType: 'script' },
  extends: ['eslint:recommended', 'google'],
  rules: {
    'require-jsdoc': 'off',
    'no-console': 'off',
    quotes: ['error', 'single', { allowTemplateLiterals: true }],
    'object-curly-spacing': ['error', 'always'],
    'max-len': ['error', {
      code: 120,
      ignoreUrls: true,
      ignoreStrings: true,
      ignoreTemplateLiterals: true,
    }],
    indent: ['error', 2, { SwitchCase: 1 }],
  },
  ignorePatterns: [
    'node_modules/**',
    '.eslintrc.js',
    '.eslintrc.cjs',
  ],
};
