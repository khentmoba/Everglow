import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

// The proof folder needs the PR number, which exists only once the PR does.
const DRAFT_FIRST = 'Open the PR as a draft first (drafts skip this check), commit the shot under docs/pr-proof/pr-<number>/, push, pin that SHA, then mark it ready.';

export function checkPrContract({body = '', draft = false, paths = []}, exists = () => true) {
  // Drafts expose incomplete work honestly and cannot be merged.
  if (draft) return [];
  body = body.replace(/<!--[\s\S]*?-->/g, '');
  const errors = [];
  for (const heading of ['Summary', 'Evidence', 'Merge Danger', 'Still to do']) {
    const section = body.match(new RegExp(`^## ${heading}\\s*\\n([\\s\\S]*?)(?=^## |$(?![\\s\\S]))`, 'm'))?.[1]?.trim();
    if (!section) errors.push(`Fill in ## ${heading}.`);
  }
  if (!/\*\*Door:\*\*\s*(one-way|two-way)\b/i.test(body)) errors.push('Declare **Door:** one-way or two-way.');
  if (!/\*\*Blast radius:\*\*\s*\S/i.test(body)) errors.push('Declare **Blast radius:**.');
  if (/\*\*Door:\*\*\s*one-way\b/i.test(body) && !/^Recovery:\s*\S/im.test(body)) errors.push('One-way changes need Recovery: failure and undo steps.');
  const visual = paths.some(path => /^(lib\/.*(?:presentation\/|theme\/|widgets\/|agent_fixtures)|assets\/images\/)/.test(path));
  const shots = [...body.matchAll(/!\[[^\]]*\]\((https:\/\/raw\.githubusercontent\.com\/khentmoba\/Everglow\/([a-f0-9]{40})\/(docs\/pr-proof\/pr-\d+\/[^)\s]+\.(?:png|jpe?g|webp)))\)/gi)];
  if (visual && shots.length === 0) errors.push(`Visual changes need a SHA-pinned screenshot under docs/pr-proof/pr-<number>/; capture blockers belong in a draft. ${DRAFT_FIRST}`);
  if (!visual && shots.length === 0 && !/Proof:\s*N\/A\s*[-—:]\s*\S/i.test(body)) errors.push('Provide proof or Proof: N/A — reason.');
  for (const shot of shots) if (!exists(shot[3], shot[2])) errors.push(`Proof is missing from its pinned commit: ${shot[3]}. ${DRAFT_FIRST}`);
  for (const label of ['Analysis', 'Tests', 'Guards', 'Browser']) {
    if (!new RegExp(`^${label}:\\s*(passed|N/A\\s*[-—:]\\s*\\S).+`, 'mi').test(body)) errors.push(`Record ${label}: passed (details), or N/A — reason.`);
  }
  if (!/^Review:\s*(?:independent|self)\s*[-—:]\s*\S/im.test(body)) errors.push('Record Review: independent — reviewer, or self — why no independent review ran.');
  if (/^- \[ \]/m.test(body) || /^(?:Blocked|Unverified):\s*(?!none\b)\S/im.test(body)) errors.push('Incomplete verification belongs in a draft.');
  return errors;
}

function existsAtCommit(path, sha) {
  try {execFileSync('git', ['cat-file', '-e', `${sha}:${path}`], {stdio:'pipe'}); return true;}
  catch {
    try {
      execFileSync('git', ['fetch', '--no-tags', '--depth=1', 'origin', sha], {stdio:'pipe'});
      execFileSync('git', ['cat-file', '-e', `${sha}:${path}`], {stdio:'pipe'});
      return true;
    } catch {return false;}
  }
}

const changedPaths = range => execFileSync('git', ['diff', '--name-only', '--no-renames', '-z', ...range], {encoding:'utf8'})
  .split('\0').filter(Boolean);

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const args = process.argv.slice(2);
    const flag = name => args.includes(name) ? args[args.indexOf(name) + 1] : undefined;
    if (flag('--body')) {
      // Local, before opening or readying the PR:
      //   node tool/ci/pr_contract.mjs --body body.md [--base origin/main]
      const paths = changedPaths([`${flag('--base') || 'origin/main'}...HEAD`]);
      const errors = checkPrContract({body: readFileSync(flag('--body'), 'utf8'), paths}, existsAtCommit);
      if (errors.length) throw new Error(errors.join('\n'));
    } else {
      const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH || args[0], 'utf8'));
      if (event.pull_request) {
        // Checkout tests a PR merge; its first parent is the actual base, even if the event is stale.
        const errors = checkPrContract({...event.pull_request, paths: changedPaths(['HEAD^1', 'HEAD'])}, existsAtCommit);
        if (errors.length) throw new Error(errors.join('\n'));
      }
    }
    console.log('[pr-contract] OK');
  } catch (error) {console.error(error.message); process.exitCode = 1;}
}
