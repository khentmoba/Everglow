# Remove an unused worktree

Use `node tool/remove_worktree.mjs ABSOLUTE_PATH INVENTORY_JSON` first.
The default is a dry-run. Add `--remove` only after all checks pass.
The command refuses dirty, unmerged, primary, unregistered, out-of-root,
or thread-owned folders. It also refuses ignored files; inspect and clear
your own build output before removal. It never forces deletion.

Before invoking it, capture a fresh complete T3 ownership inventory:

1. Record the capture start time in UTC.
2. Call `t3_thread_list` for this project, including subagents. Read every page.
3. Call `t3_thread_read` for every returned thread. Retain `threadId`,
   `worktreePath`, `settled`, `archived`, and `status` from each thread record.
4. Write a temporary JSON file outside the repository:

```json
{
  "capturedAt": "2026-10-08T00:00:00.000Z",
  "complete": true,
  "threads": [
    {
      "threadId": "example",
      "worktreePath": "C:/Users/Admin/.t3/worktrees/Everglow/example",
      "settled": false,
      "archived": false,
      "status": "completed"
    }
  ]
}
```

Keep every thread, including idle and completed threads. Set `complete`
only after every page and ownership record has been read. A thread still
owns its folder until settled or archived; a running thread always owns it.
The inventory must be at most 30 seconds old when removal begins. Recapture
it for `--remove` if the dry-run expires it. If T3 access or a complete fresh
inventory is unavailable, leave the folder in place. Stop on any removal error.

This snapshot check cannot lock T3 against a new attachment during removal.
Avoid cleanup while another operator is assigning folders. It prevents the
observed mistake of deleting a folder already owned by an active session.
