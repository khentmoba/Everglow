import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

export function checkPrContract({body = '', draft = false, paths = []}, exists = () => true) {
  // Drafts expose incomplete work honestly and cannot be merged.
  if (draft) return [];
  body = body.replace(/<!--[\s\S]*?-->/g, '');
  const errors = [];
  for (const heading of ['Summary', 'Evidence', 'Merge Danger']) {
    const section = body.match(new RegExp(`^## ${heading}\\s*\\n([\\s\\S]*?)(?=^## |$(?![\\s\\S]))`, 'm'))?.[1]?.trim();
    if (!section) errors.push(`Fill in ## ${heading}.`);
  }
  if (!/\*\*Door:\*\*\s*(one-way|two-way)\b/i.test(body)) errors.push('Declare **Door:** one-way or two-way.');
  if (!/\*\*Blast radius:\*\*\s*\S/i.test(body)) errors.push('Declare **Blast radius:**.');
  if (/\*\*Door:\*\*\s*one-way\b/i.test(body) && !/^Recovery:\s*\S/im.test(body)) errors.push('One-way changes need Recovery: failure and undo steps.');
  const visual = paths.some(path => /^(lib\/.*(?:presentation\/|theme\/|widgets\/|agent_fixtures)|assets\/images\/)/.test(path));
  const shots = [...body.matchAll(/!\[[^\]]*\]\((https:\/\/raw\.githubusercontent\.com\/khentmoba\/Everglow\/([a-f0-9]{40})\/(docs\/pr-proof\/[^)\s]+\.(?:png|jpe?g|webp)))\)/gi)];
  if (visual && shots.length === 0) errors.push('Visual changes need a SHA-pinned screenshot; capture blockers belong in a draft.');
  if (!visual && shots.length === 0 && !/Proof:\s*N\/A\s*[-—:]\s*\S/i.test(body)) errors.push('Provide proof or Proof: N/A — reason.');
  for (const shot of shots) if (!exists(shot[3], shot[2])) errors.push(`Proof is missing from its pinned commit: ${shot[3]}`);
  for (const label of ['Analysis', 'Tests', 'Guards', 'Browser']) {
    if (!new RegExp(`^${label}:\\s*(passed|N/A\\s*[-—:]\\s*\\S).+`, 'mi').test(body)) errors.push(`Record ${label}: passed (details), or N/A — reason.`);
  }
  if (/^- \[ \]/m.test(body) || /^(?:Blocked|Unverified):\s*(?!none\b)\S/im.test(body)) errors.push('Incomplete verification belongs in a draft.');
  return errors;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH || process.argv[2], 'utf8'));
    if (event.pull_request) {
      const pr = event.pull_request;
      const paths = execFileSync('git', ['diff', '--name-only', '--no-renames', '-z', pr.base.sha, 'HEAD'], {encoding:'utf8'}).split('\0').filter(Boolean);
      const errors = checkPrContract({...pr, paths}, (path, sha) => {
        try {execFileSync('git', ['cat-file', '-e', `${sha}:${path}`], {stdio:'pipe'}); return true;}
        catch {
          try {
            execFileSync('git', ['fetch', '--no-tags', '--depth=1', 'origin', sha], {stdio:'pipe'});
            execFileSync('git', ['cat-file', '-e', `${sha}:${path}`], {stdio:'pipe'});
            return true;
          } catch {return false;}
        }
      });
      if (errors.length) throw new Error(errors.join('\n'));
    }
    console.log('[pr-contract] OK');
  } catch (error) {console.error(error.message); process.exitCode = 1;}
}
