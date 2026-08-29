---
name: vite-plus
description: Use the Vite+ `vp` CLI for project creation and migration, dependencies, Node environments, dev/build/test/check workflows, monorepo tasks, caching, and Vite+ configuration. Trigger for Vite+, Vite Plus, `vp`, or migration to consolidated Vite/Vitest/Oxlint/Oxfmt/Rolldown tooling.
metadata:
  version: "0.3.0"
---

# Vite+

Use the installed `vp` CLI as the source of truth. Inspect its version and help
before relying on remembered flags:

```bash
vp --version
vp --help
vp <command> --help
vp toolchain
```

When latest-release behavior matters, run `vp upgrade --check` and retrieve
<https://viteplus.dev/llms.txt> plus the stable `voidzero-dev/vite-plus`
release. Vite+ is pre-1.0, so avoid hardcoding transient details when help or
current docs can answer them.

## Use Vite+ consistently

In a Vite+ project, prefer:

- `vp install`, `vp add`, `vp remove`, and other `vp` package commands.
- `vp dev`, `vp build`, and `vp preview` for application lifecycle.
- `vp test` for built-in Vitest; `vp test watch` for watch mode.
- `vp check` for format, lint, and type validation; `vp check --fix` for safe
  automated fixes.
- `vp run <script-or-task>` for package scripts and monorepo tasks. `vp run
  test` runs `package.json`'s script, while `vp test` invokes built-in Vitest.

## Create and migrate

Discover current templates before creating:

```bash
vp create --help
vp create --list
vp create vite:application --directory my-app
vp create vite -- --template react-ts
```

Templates can be built-in, local generator config, npm create packages, org
catalog entries, or GitHub templates. Use explicit directory, package-manager,
agent/editor, hooks, git, and build-script approval options when reproducibility
matters. Review packages before using `--approve-builds`.

Before migration, inspect `vp migrate --help`, the repository, and its git
state. Normally migrate from the workspace root:

```bash
vp migrate --no-interactive
```

For an existing Vite+ project, plain `vp migrate` upgrades local toolchain pins;
use `--full` only when hooks, editor/agent files, and first-migration steps
should be rerun. Trust the installed migrator over remembered rewrite rules,
then inspect every diff. In particular, do not blindly delete package-manager
aliases used to unify bundled Vite/Vitest peer resolution.

Validate migrations with:

```bash
vp install
vp check
vp test
vp build
```

## Configuration and tasks

Vite+ uses `vite.config.ts` with `defineConfig` from `vite-plus`. Keep supported
Vite, test, lint, format, task, and staged-file settings there, following the
installed config schema and nearby project conventions.

Use `vp run`/`vpr` for cached, dependency-aware workspace tasks:

```bash
vp run
vp run build
vp run -r build
vp run --filter '@scope/*' build
vp run --fail-if-no-match --filter './apps/*' build
vp run --last-details
```

Check `vp run --help` before advanced filtering. A filter that matches nothing
succeeds by default; use `--fail-if-no-match` in CI when that should fail. Put
cache-affecting variables in task `env`; reserve `untrackedEnv` for values that
must pass through without affecting cache keys.

## Node and global installation

Use `vp env` to resolve, pin, install, and diagnose Node versions from project
metadata:

```bash
vp env current --json
vp env doctor
vp env pin lts
vp env install
vp env exec --node lts node -v
```

Vite+ 0.3 introduced an optional split platform-directory layout. Existing
single-root installs under `~/.vite-plus` remain supported and upgrades do not
move them automatically. Follow the current upgrade guide before imploding or
reinstalling an existing environment.

Use `vp install -g <package>` when a global package should be managed through
Vite+. Use `vp upgrade` only for the global `vp` binary; update a project's
local `vite-plus` package with normal Vite+ package commands.

## CI and validation

- Use `vp install --frozen-lockfile` in CI.
- Prefer `voidzero-dev/setup-vp@v1` in GitHub Actions.
- Pin Vite+ container images by exact tag or digest. They are build images, not
  production runtimes.
- Run `vp check` after changes and add focused tests/builds when behavior or
  output can change.
- Report commands, failures, generated/configuration changes, and manual
  follow-up.
