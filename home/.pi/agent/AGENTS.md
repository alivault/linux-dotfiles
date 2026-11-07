# Global Agent Instructions

- Always write in Simplified Technical English (ASD-STE100) and follow Zinsser's four principles of quality writing: Simplicity, Brevity, Clarity, Humanity.
- When you need all of a file's content, read the whole file. Tool outputs can be truncated; if a read is truncated, continue reading with offsets/limits until you have the complete file.

## Deleting files

- Never use `rm` to delete files. Use `gio trash` instead, so deleted files can be recovered from the Trash.
- Exception: scratch files and folders that you or another agent made in `~/.cache` (test releases, nested homes, build output, logs) may always be deleted with `rm -rf`, without asking. This includes large trees there. It does not cover what apps keep in `~/.cache` (their caches), and nothing outside `~/.cache`.
- Never put a build tree in the Trash (makepkg `src/` and `pkg/`, cargo `target/`, a kernel or other build directory): when the Trash is emptied, tens of thousands of files keep `gvfsd-metadata` busy for an hour, and every app that reads file metadata waits 25 s per call (2026-10-29). Let the build tool remove it (`makepkg --clean`, `cargo clean`, `make clean`), or ask the user.
- `rm` is guarded for agents (`~/.local/share/agent-guard/bin/rm`). It refuses `/`, top-level directories, your home directory and what is directly in it, the directories directly in `~/.config`, `~/.local/share`, `~/.local/state` and `~/code`, and git repositories. Do not get around it with `/usr/bin/rm`; ask the user.

## Shell

- Each bash tool call runs in a new shell. A variable, `export` or `cd` from an earlier call is gone in the next one. Set a variable in the same call that uses it.
- An unset variable is an error (`set -u`, from pi's `shellCommandPrefix`). Write `${VAR:-}` where empty is correct.

## Subagents

- When a subagent is done (merged, or dropped), archive it (`agents` archive) and delete its worktree and its branch, local and remote (`git worktree remove`, `git branch -d`, `git push origin --delete`). Keep a worktree only while its work is not merged.

## Git

- When you finish a change, commit it and push it. Do not wait for the user to ask.
- Push work to its remote as soon as it is committed. A repository without a remote, or with commits that are not pushed, can be lost with the disk.
