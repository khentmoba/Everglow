const js = require('@eslint/js');
const globals = require('globals');

module.exports = [
  {
    ignores: [
      'node_modules/**',
      'coverage/**',
    ],
  },
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: 'commonjs',
      globals: {
        ...globals.node,
        ...globals.es2024,
      },
    },
    rules: {
      // Deliberate starting points, to be tightened one module at a time:
      //  - caughtErrors 'none' + allowEmptyCatch keep the ~49 silent
      //    try/catch sites out of this PR. Purging them (log, or narrow the
      //    catch) is the job of fix/kill-silent-catches-data-paths; flip
      //    both once that lands.
      //  - max-len is 'warn' for the same reason — see its note below.
      'no-unused-vars': [
        'error',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
          caughtErrors: 'none',
        },
      ],
      'no-undef': 'error',
      'no-constant-condition': ['error', { checkLoops: false }],
      'no-empty': ['error', { allowEmptyCatch: true }],
      // max-len: awareness mode. 16k lines of server code predates this
      // rule, so the limit is a warning, not a gate — CI stays green while
      // we burn it down module by module (motchi_chat.js is done first).
      // CI runs `eslint . --max-warnings <budget>` so NEW long lines still
      // fail the PR; the budget only ever goes down. Ignores follow the
      // rule's own escape hatches: Motchi's prompt prose, long data strings,
      // regex literals and URLs are intentional and should not be wrapped.
      'max-len': ['warn', {
        code: 120,
        ignoreStrings: true,
        ignoreTemplateLiterals: true,
        ignoreRegExpLiterals: true,
        ignoreUrls: true,
        ignoreComments: true,
      }],
    },
  },
];
