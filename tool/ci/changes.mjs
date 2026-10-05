import {execFileSync} from 'node:child_process';
import {appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

const keys = ['app', 'browser', 'web', 'backend', 'security', 'audit'];
const full = () => Object.fromEntries(keys.map(key => [key, true]));

export function selectChecks(paths) {
  if (paths == null) return full();
  const checks = Object.fromEntries(keys.map(key => [key, false]));
  const enable = (...names) => names.forEach(name => { checks[name] = true; });
  for (const path of paths) {
    if (path.startsWith('.github/workflows/') || path.startsWith('tool/ci/')) return full();
    if (path.startsWith('functions/')) {
      enable('backend', 'security');
      if (/^functions\/package(?:-lock)?\.json$/.test(path)) enable('audit');
    } else if (['firebase.json', '.firebaserc'].includes(path)) {
      enable('web', 'backend', 'security');
    } else if (['firestore.rules', 'storage.rules', 'firestore.indexes.json', 'firebase.emulators.json'].includes(path)) {
      enable('security');
    } else if (path.startsWith('lib/')) {
      enable('app', 'web');
      if (!path.startsWith('lib/features/') || /^lib\/features\/(anime|ai|cinema|jukebox)\//.test(path)) enable('browser');
      if (/auth|access|permission|core\/config/.test(path)) enable('security');
    } else if (path.startsWith('test/')) {
      enable('app');
      if (/^test\/(core|shared|features\/(anime|ai|cinema|jukebox))\//.test(path) || path === 'test/embedded_media_web_memory_test.dart') enable('browser');
    } else if (path.startsWith('assets/') || path.startsWith('web/') || /^pubspec\.(yaml|lock)$/.test(path)) {
      enable('app', 'browser', 'web');
    } else if (path === 'analysis_options.yaml') {
      enable('app');
    } else if (/^tool\/(build_web|build_stamp|generate_sw)\.dart$/.test(path) || path === 'tool/service_worker_test.mjs') {
      enable('web');
    } else if (path.startsWith('tool/perf/') || path.startsWith('docs/') ||
        (path.startsWith('.agents/skills/') && path.endsWith('.md')) || /^[^/]+\.md$/.test(path) ||
        ['.gitignore', '.gitattributes', '.editorconfig', 'LICENSE', '.github/pull_request_template.md'].includes(path)) {
      // Guards still run; agents run browser tooling checks when these tools change.
    } else {
      return full(); // Unknown inputs must never silently bypass verification.
    }
  }
  return checks;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let paths = null; // Dispatches and unavailable history get a complete run.
  if (process.env.BASE_SHA) {
    try {
      // Both sides of renames matter: moving backend code into docs deletes code.
      paths = execFileSync('git', ['diff', '--no-renames', '--name-only', '-z', process.env.BASE_SHA, 'HEAD', '--'],
        {encoding:'utf8', stdio:['ignore', 'pipe', 'pipe']}).split('\0').filter(Boolean);
    } catch {
      process.stderr.write('Could not read the PR diff; running all checks.\n');
    }
  }
  const output = Object.entries(selectChecks(paths)).map(([key, value]) => `${key}=${value}\n`).join('');
  if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, output);
  process.stdout.write(output);
}
