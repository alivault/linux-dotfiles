---
name: tanstack-cli
description: Use the TanStack CLI to create TanStack Start or Router apps, discover and apply add-ons, retrieve official TanStack docs, inspect ecosystem metadata, author templates/add-ons, and pin TanStack versions. Trigger for `tanstack` CLI work and TanStack library documentation.
metadata:
  version: "0.3.0"
---

# TanStack CLI

Use the installed CLI and its current catalog as the source of truth. TanStack
commands, flags, add-on IDs, compatibility rules, and library APIs change.

## Start with discovery

```bash
tanstack --version
tanstack --help
tanstack <command> --help
```

When "latest" matters, compare with `npm view @tanstack/cli version` and inspect
the package-specific stable release. Prefer `--json` for automation.

Match the target project's framework and installed major versions. Search and
fetch official, versioned documentation before answering API questions:

```bash
tanstack libraries --json
tanstack search-docs "route loaders" --library router --framework react --json
tanstack doc router framework/react/guide/data-loading
tanstack doc query framework/react/overview --docs-version v5
```

The fetch command is singular: `tanstack doc`. Use `libraries` to discover IDs.
Convert a result URL to its library and path by removing the TanStack host,
library/version/docs prefix, query, and anchor. Use documented major labels such
as `v1` or `v5`, not an npm patch version. Cite pages used for behavior claims.

## Create applications

`tanstack create` defaults to TanStack Start. Use `--router-only` for a
file-routed Router SPA and `--blank` for a minimal scaffold.

```bash
tanstack create --help
tanstack create --list-add-ons --framework React --json
tanstack create --addon-details drizzle --framework React --json
tanstack create my-app --package-manager pnpm \
  --add-ons tanstack-query,drizzle --no-examples --intent -y
```

- Discover add-ons and their options, dependencies, supported modes, and
  conflicts instead of guessing IDs or combinations.
- Use `--template`; `--starter` is deprecated.
- Standard scaffolds include Tailwind. Use `--blank` when a minimal app without
  Tailwind/examples/devtools/tests is wanted; legacy Tailwind flags are
  compatibility flags.
- Router-only mode excludes Start-oriented templates, deployments, and general
  add-ons. Confirm current help for toolchain support.
- Use `--intent` deliberately when agent mappings are wanted.
- Inspect a non-empty destination before using `--force`; do not overwrite
  user files without approval.

## Existing projects and add-ons

Current TanStack scaffolds use `.cta.json` at the application root. Inspect it,
the git state, and add-on details before running:

```bash
tanstack add --help
tanstack add tanstack-query drizzle
```

Avoid `--forced`: it bypasses conflict and overwrite protection. After adding,
review source and manifest diffs, `.env.example`, generated demos, integration
hooks, and dependency changes. The ecosystem catalog is discovery metadata, not
proof that an add-on with the same ID exists:

```bash
tanstack ecosystem --category database --json
tanstack clean-demos --dry-run
```

## Less common workflows

Inspect subcommand help before using these:

```bash
tanstack template init       # then edit metadata and compile
tanstack template compile
tanstack add-on init         # then edit .add-on metadata/assets
tanstack add-on compile
tanstack add-on dev
tanstack pin-versions
```

Test templates and add-ons against clean scaffolds. `pin-versions` removes range
prefixes from TanStack packages and may add missing peers; review manifest and
lockfile changes, reinstall, and validate. Do not run it merely because updates
exist.

The old CLI-level `tanstack mcp` command is removed. Use JSON-capable
`libraries`, `doc`, `search-docs`, `ecosystem`, and create-discovery commands.
An application add-on named `mcp`, when present in the catalog, is separate.

TanStack CLI telemetry can be inspected or disabled with:

```bash
tanstack telemetry status
tanstack telemetry disable
```

Honor `DO_NOT_TRACK=1` or `TANSTACK_CLI_TELEMETRY_DISABLED=1` in automation.

## Validation

After scaffolding or add-on changes, inspect the diff and run the generated
project's install, typecheck/lint, tests, and build scripts as available. Report
commands, modified/generated files, required environment variables, and manual
follow-up.
