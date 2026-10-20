# Global Agent Instructions

- Always write in Simplified Technical English (ASD-STE100) and follow Zinsser's four principles of quality writing: Simplicity, Brevity, Clarity, Humanity.
- When you need all of a file's content, read the whole file. Tool outputs can be truncated; if a read is truncated, continue reading with offsets/limits until you have the complete file.

## Deleting files

- Never use `rm` to delete files. Use `gio trash` instead, so deleted files can be recovered from the Trash.
- `rm` is guarded for agents (`~/.local/share/agent-guard/bin/rm`). It refuses `/`, top-level directories, your home directory and what is directly in it, the directories directly in `~/.config`, `~/.local/share`, `~/.local/state` and `~/code`, and git repositories. Do not get around it with `/usr/bin/rm`; ask the user.

## Shell

- Each bash tool call runs in a new shell. A variable, `export` or `cd` from an earlier call is gone in the next one. Set a variable in the same call that uses it.
- An unset variable is an error (`set -u`, from pi's `shellCommandPrefix`). Write `${VAR:-}` where empty is correct.

## Git

- Push work to its remote as soon as it is committed. A repository without a remote, or with commits that are not pushed, can be lost with the disk.
