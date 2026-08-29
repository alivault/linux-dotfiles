---
name: react-typescript
description: Build and maintain React applications with TypeScript. Use for TSX, component and hook typing, React 19 APIs, React Compiler, Actions, Activity, use(), useEffectEvent, refs, effects, context, and React-oriented TypeScript configuration.
metadata:
  version: "0.2.0"
---

# React + TypeScript

Follow the target repository before generic advice. Inspect `package.json`, the
lockfile, TypeScript config, framework config, lint rules, and nearby code. Match
the installed React, React DOM, TypeScript, framework, and compiler versions.
Do not silently upgrade a project or apply current APIs to an older major.

For version-sensitive behavior, retrieve current official documentation:

- React: <https://react.dev/reference/react>
- React Compiler: <https://react.dev/learn/react-compiler>
- TypeScript release notes: <https://www.typescriptlang.org/docs/handbook/release-notes/overview.html>
- TypeScript module guidance: <https://www.typescriptlang.org/docs/handbook/modules/guides/choosing-compiler-options.html>

## Component and type defaults

- Prefer plain function components. Do not use `React.FC` without a project
  reason.
- Extend intrinsic elements with `React.ComponentProps<"button">` rather than
  manually recreating DOM attributes.
- Let contextual typing infer inline event types. For extracted handlers use
  types such as `React.ChangeEvent<HTMLInputElement>` or
  `React.FormEvent<HTMLFormElement>`.
- Model mutually exclusive props and async state with discriminated unions.
- Use `satisfies` when an object must retain literal keys while checking a
  broader shape.
- Keep contexts type-safe: use a real default when one exists; otherwise use a
  nullable context plus a guarded consumer hook.
- Follow the project's named-import or `React.*` namespace style consistently.

```tsx
type ButtonProps = React.ComponentProps<"button"> & {
  variant?: "primary" | "ghost"
}

function Button({ variant = "primary", ...props }: ButtonProps) {
  return <button data-variant={variant} {...props} />
}

type RequestState<T> =
  | { status: "idle" | "loading" }
  | { status: "error"; error: Error }
  | { status: "success"; data: T }
```

## React 19 guidance

### Refs

For new React 19 code, accept `ref` as a prop. `forwardRef` is unnecessary in
React 19 and is planned for eventual deprecation, but remains valid. Do not
mechanically rewrite established components, compatibility layers, or libraries
that support React 18.

```tsx
function Input({ ref, ...props }: React.ComponentProps<"input">) {
  return <input ref={ref} {...props} />
}
```

Callback refs may return cleanup functions. Avoid implicit returns that return
the DOM node or an assignment result.

### `use()` and context

`use()` can read context or a compatible promise and may be called
conditionally, but only from a component or Hook. Promises should come from a
framework loader, cache, server, or parent; do not create a fresh promise during
render. `useContext()` remains valid—prefer whichever fits the local code.

### Actions

Use form Actions, `useActionState`, `useFormStatus`, `useOptimistic`, and async
transitions when they simplify pending/error/optimistic state. Preserve
accessible form semantics and handle rejected async work. Check framework
conventions before mixing client Actions with server functions.

### React 19.2 APIs

- `<Activity mode="hidden">` preserves state, hides the DOM, cleans up effects,
  and defers updates. Use it when preservation or pre-rendering matters, not as
  a replacement for every conditional.
- `useEffectEvent` is for non-reactive event-like logic fired by an Effect. Call
  Effect Events only from Effects in the same component or Hook; do not pass
  them to children or use them to silence dependency linting.
- `cacheSignal` and partial pre-render/resume APIs are server/RSC concerns.
  Follow the framework's support and rendering model rather than wiring them
  into ordinary client applications.

## React Compiler

React Compiler is stable but optional. Before relying on automatic
memoization, verify that the project enables it through its framework or build
configuration (for example `babel-plugin-react-compiler`) and that its lint
rules pass.

- With the compiler enabled, do not add routine `memo`, `useMemo`, or
  `useCallback` solely to prevent ordinary rerenders.
- Without the compiler, use manual memoization only for measured performance,
  expensive work, or required stable identity—not by default.
- Do not remove existing memoization during unrelated work. React recommends
  testing removals because they can alter compiler output and behavior.
- Stable identity can still be required by an Effect dependency or third-party
  API even when the compiler is enabled.

## Effects and client/server boundaries

- Effects synchronize with external systems. Derive render data during render
  and handle user events in event handlers instead of adding Effects.
- Include reactive dependencies; restructure code or use `useEffectEvent`
  rather than suppressing the hooks linter.
- Clean up subscriptions, timers, observers, and in-flight work.
- Apply `"use client"` only in frameworks that implement React Server
  Components. Put the boundary at the smallest practical interactive subtree.
  Ordinary Vite SPAs do not need client directives.

## TypeScript configuration

There is no universal React `tsconfig`. Extend or preserve framework-generated
configuration and change options only for a concrete requirement.

- For a browser application bundled by Vite, current templates use
  `module: "esnext"`, `moduleResolution: "bundler"`, `noEmit: true`,
  `isolatedModules: true`, `verbatimModuleSyntax: true`, and
  `jsx: "react-jsx"`.
- For code emitted and executed directly by modern Node.js, use the appropriate
  Node mode such as `nodenext`; it is not the default choice for a Vite browser
  application.
- Libraries need configuration based on their emitted JS, declaration output,
  bundling, package exports, and supported consumers.
- Prefer `strict`. Add stricter options such as `noUncheckedIndexedAccess` and
  `exactOptionalPropertyTypes` deliberately because they can require broad
  project changes.
- Match the installed TypeScript release. Do not assume TypeScript 5.9; review
  current release notes and migration/deprecation guidance for newer majors.

## Validation

After changes, run the repository's formatter/linter, TypeScript check, focused
tests, and build as applicable. Report commands run, failures, and any behavior
that depends on a particular React, TypeScript, compiler, or framework version.
