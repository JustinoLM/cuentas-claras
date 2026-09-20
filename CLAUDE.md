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
- Read-only git commands (`git status`, `git diff`, `git log`, `git branch --show-current`) may be run directly to gather context — use them so any proposed command has real paths filled in, instead of asking the project owner to run them and paste the output back.
- Never run a git command that changes repository state: `add`, `commit`, `push`, `checkout`, creating a branch, `merge`, `tag`. Instead, give the exact command(s) and a short explanation of why each one is structured that way, then let the project owner run them. This applies to every such operation, everything in `docs/git-workflow.md`.
- Before starting work on a new Issue or section of the spec, state whether it belongs on the current branch or needs a new one. If it needs a new one, give the `git checkout -b feature/...` (or `fix/...`) command first and wait for confirmation that the project owner is on that branch before editing any files.
- When a change is finished, always end the turn with the git command(s) for it (add + commit, in Conventional Commits format) and a short explanation. Then wait for the project owner to confirm they ran it before starting the next task. Do not move on to the next step on your own.
- Do not add `Co-Authored-By` or any other AI-attribution line to commit messages or PR descriptions.
- Never run `xcodebuild` or any command that touches the iOS Simulator directly, and do not hand over an `xcodebuild` terminal command as a substitute either — the project owner's Xcode is in English. The basic flow (Cmd+U to run tests, Cmd+9 for the Report Navigator to check the result) is already known — just say "run the tests" or name the shortcut inline, don't re-explain the full sequence every time. Only spell out full manual steps (exact keyboard shortcuts and real English menu/panel names) the first time a new kind of check comes up, or when something about the flow changes (a different destination, a different panel). Wait for them to do it and report back the result; don't assume something worked without that confirmation.
- Cuando algo requiera probarse en el Simulator más allá de correr los tests (verificar una pantalla, tocar un flujo, revisar comportamiento visual), no lo hagas tú — describe paso a paso qué hacer y qué esperar ver, la primera vez con detalle y luego de forma breve, igual que con los tests.
- Some things cannot be verified in the Simulator at all — notably VisionKit's `DataScannerViewController` (Vía 1, QR scanning), since `DataScannerViewController.isSupported` is always `false` on Simulator; it needs real camera hardware. When a task needs one of those, say explicitly that it requires a real device and why, then give the manual steps: connect the iPhone, pick it from the destination dropdown next to the scheme selector (same place as the Simulator), press Cmd+R to build and run on it. First time only: unlock the phone and tap "Trust" on the "Trust This Computer" prompt, and if Xcode asks, enable Developer Mode on the device (Settings > Privacy & Security > Developer Mode), which requires a reboot.

## Documentation

- Code comments and any new project docs in English, except where a Panama/DGI-specific term is the correct term to use as-is.
- Commit message format is defined in `docs/git-workflow.md`. Follow it.

## Communication style

- Concise. No filler, no restating the request before doing it, no summary of obvious steps.
- No emojis.
- No em dashes.
- State problems and tradeoffs directly. Do not soften bad news or hedge on uncertainty.

## Reference

The full spec is `docs/spec-invoice-scanner.md`. Section 18 (roadmap) has a status line at the top saying which phase is current and which is done — check it before starting work. Work section by section within the current phase. Do not build ahead into a later phase without being asked.
