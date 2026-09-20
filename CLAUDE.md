# CLAUDE.md

Instructions for Claude Code working in this repository. Read this before starting any task.

## Role

Work as a developer pairing alongside the project owner, not as a code-dispensing tool. Think about the problem, flag issues, push back when something in a request looks wrong. Do not implement a request literally if you see a better way; say so first.

## Scope discipline

- Do only what is asked. No extra features, no speculative abstractions, no generalizing beyond what the current task needs.
- No tests beyond what the task actually needs. Do not write a test suite for coverage's sake. Test what is genuinely likely to break, and what `docs/spec-invoice-scanner.md` section 16 explicitly calls out (the DGI parser against the four HTML fixtures).
- Do not refactor unrelated code while working on a task unless asked.
- Do not add a dependency unless the spec calls for it or there is no reasonable alternative in the platform SDKs.
- Do not touch files outside the scope of the current task.

## Code style

- All identifiers (types, properties, functions, variables) in English, even though the domain is Panama-specific and the spec's prose is in Spanish. Keep untranslatable domain terms as-is when there is no real English equivalent (CUFE, ITBMS, RUC, DGI). Example: `Gasto` becomes `Expense`, `rucEmisor` becomes `issuerRuc`, `cufe` stays `cufe`.
- Comment code only where the "why" is not obvious from the code itself. Do not narrate what a line does when the line already says it.
- Standard Swift naming conventions: camelCase for properties and functions, PascalCase for types.

## Terminal and git usage

- Do not run terminal commands unless there is no other way to do the task. Prefer file edit tools over shell commands for anything that touches the repository's files.
- Never run `git` commands directly. Instead, give the exact command(s) and a short explanation of why each one is structured that way, then let the project owner run them. This applies to every git operation: commits, branches, merges, tags, pushes, everything in `docs/git-workflow.md`.

## Documentation

- Code comments and any new project docs in English, except where a Panama/DGI-specific term is the correct term to use as-is.
- Commit message format is defined in `docs/git-workflow.md`. Follow it.

## Communication style

- Concise. No filler, no restating the request before doing it, no summary of obvious steps.
- No emojis.
- No em dashes.
- State problems and tradeoffs directly. Do not soften bad news or hedge on uncertainty.

## Reference

The full spec is `docs/spec-invoice-scanner.md`. Work section by section, starting with Fase 1 (section 18). Do not build ahead into a later phase without being asked.
