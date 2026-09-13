---
name: tanstack-cli
description: >
  Use the TanStack CLI for app scaffolding, add-ons, and versioned TanStack
  documentation lookup. Applies to CLI operations and TanStack API research.
metadata:
  version: "0.3.0"
---

# TanStack CLI

## Discovery

Use the installed CLI for supported commands and flags. Check `tanstack --version`
and relevant `tanstack <command> --help` when needed; reuse verified results within
the task. Prefer `--json` for discovery. If the CLI is unavailable, use the
[official documentation](https://tanstack.com/cli/latest/docs/cli-reference).

For latest-version questions, compare `npm view @tanstack/cli version` with the
installed version and the matching package release in
[TanStack/cli](https://github.com/TanStack/cli/releases).

## Documentation lookup

Match the project's framework and installed library version. Find and fetch the
relevant official page; reuse sources already checked for the task.

```bash
tanstack libraries --json
tanstack search-docs "<query>" --library <id> --framework <framework> --json
tanstack doc <library> <path> --docs-version <version>
```

Discover library IDs when unknown. Convert a result URL to its library and
relative documentation path, omitting the URL prefix, version segment, query,
and anchor. Documentation versions are labels such as `v1` or `v5`, not npm
patch versions. Cite the specific pages used.

## Scaffolding and add-ons

`tanstack create` defaults to Start with SSR. `--router-only` creates a Router
SPA and restricts add-ons, deployment, and templates; check current help for
compatible choices.

Where supported, `--blank` omits the starter UI, examples, Tailwind, devtools,
tests, and Intent setup. `--no-examples` only removes examples. Check flag
availability before using newer scaffold modes.

Discover integrations before choosing them:

```bash
tanstack create --list-add-ons --framework React --json
tanstack create --addon-details <id> --framework React --json
```

Use the target framework. Inspect compatibility, dependencies, configuration
options, and conflicts; ecosystem partner IDs are not necessarily add-on IDs.
For existing projects, inspect `.cta.json` and current files before `tanstack add`.
Avoid overwrite or conflict-bypass flags unless the requested change requires
them and the affected files have been reviewed.

After changes, review generated files, dependencies, environment requirements,
and demo routes; run the project's relevant checks.

For template authoring, custom add-ons, version pinning, or telemetry controls,
consult command help and the linked CLI reference only when those operations
are needed.
