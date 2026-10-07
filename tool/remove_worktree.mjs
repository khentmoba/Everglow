// Node 22+. Dry-run by default. Supply a fresh complete T3 inventory.
import {execFileSync} from 'node:child_process';
import {readFileSync, realpathSync, lstatSync} from 'node:fs';
import {resolve, dirname, join} from 'node:path';
import {pathToFileURL} from 'node:url';

const canonical = path => resolve(path).replaceAll('\\', '/').toLowerCase();

export function checkOwnership(inventory, target, now = Date.now()) {
  const age = now - Date.parse(inventory.capturedAt);
  if (inventory.complete !== true || !Array.isArray(inventory.threads) ||
      !Number.isFinite(age) || age < 0 || age > 30000) {
    throw new Error('Need a complete T3 inventory captured within 30 seconds.');
  }
  for (const thread of inventory.threads) {
    if (!thread.threadId || !Object.hasOwn(thread, 'worktreePath') ||
        typeof thread.settled !== 'boolean' || typeof thread.archived !== 'boolean' ||
        !['idle','preparing','queued','starting','running','waiting','completed','interrupted','failed','cancelled','rolled_back'].includes(thread.status)) {
      throw new Error('Incomplete thread ownership record.');
    }
    if (thread.worktreePath && canonical(thread.worktreePath) === canonical(target) &&
        (!thread.settled && !thread.archived ||
          ['preparing', 'queued', 'starting', 'running', 'waiting'].includes(thread.status))) {
      throw new Error(`Worktree belongs to thread ${thread.threadId}; leave it in place.`);
    }
  }
}

export function removeWorktree(target, inventoryFile, {remove = false} = {}) {
  target = realpathSync(target);
  const root = realpathSync(join(process.env.USERPROFILE || process.env.HOME, '.t3/worktrees/Everglow'));
  if (canonical(dirname(target)) !== canonical(root)) {
    throw new Error('Target must be directly inside the Everglow T3 worktree folder.');
  }
  if (!lstatSync(join(target, '.git')).isFile()) {
    throw new Error('Target is not a linked Git worktree.');
  }
  const git = (...args) => execFileSync('git', ['-C', target, ...args], {encoding: 'utf8'}).trim();
  const entries = git('worktree', 'list', '--porcelain').split('\n\n');
  if (!entries.slice(1).some(entry => entry.split('\n').includes(`worktree ${target.replaceAll('\\', '/')}`))) {
    throw new Error('Target is not a registered secondary worktree.');
  }
  if (git('status', '--porcelain', '--untracked-files=all')) throw new Error('Worktree has local changes.');
  if (git('ls-files', '--others', '--ignored', '--exclude-standard')) {
    throw new Error('Worktree has ignored files; inspect them before cleanup.');
  }
  git('fetch', 'origin', 'main');
  git('merge-base', '--is-ancestor', 'HEAD', 'origin/main');
  // Read last, immediately before removal. An unavailable/stale inventory fails closed.
  checkOwnership(JSON.parse(readFileSync(inventoryFile, 'utf8')), target);
  if (remove) git('worktree', 'remove', target);
  return `${remove ? 'Removed' : 'Safe to remove (dry-run)'}: ${target}`;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const [target, inventory, flag] = process.argv.slice(2);
    if (!target || !inventory || flag && flag !== '--remove') {
      throw new Error('Usage: node tool/remove_worktree.mjs ABSOLUTE_PATH INVENTORY_JSON [--remove]');
    }
    console.log(removeWorktree(target, inventory, {remove: flag === '--remove'}));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
