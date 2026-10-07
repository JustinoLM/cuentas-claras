# Cuentas Claras

iOS app to scan Panama DGI electronic invoices (SFEP) and track personal expenses, local-first.

**Status**: Fase 5 (code complete for v1.0.0) complete — tag `v1.0.0`. App Store publication is pending (`docs/app-store-publication.md`). See `docs/spec-invoice-scanner.md` section 18 for the roadmap and current phase.

## What it does

Scans the QR code on a Panama electronic invoice, looks up the CUFE against the DGI's public consultation endpoint, and stores the parsed invoice locally. Expenses can be browsed and charted in the app with no account required. Exporting to Excel (via a file the user picks) and syncing to OneDrive are optional, on top of that local core.

## Design principles

- **Local-first.** The core app works with zero external accounts.
- **No AI, no backend.** Everything ships on-device. No servers operated by the developer, no automated categorization.
- **Barebones.** The simplest solution that solves the real problem, not the most complete one.

Full rationale and the complete technical spec: [`docs/spec-invoice-scanner.md`](docs/spec-invoice-scanner.md).

## Requirements

- Xcode 27+ (the project's pbxproj format needs it; CI runs on the `xcode-27` runner image for the same reason — see `docs/git-workflow.md`)
- iOS 18+ deployment target (real minimum is iOS 17, for SwiftData; 18 leaves a margin)
- A physical iPhone for testing the QR scanner — the Simulator does not support live camera capture (`DataScannerViewController.isSupported` is always `false` there)

## Setup

1. Clone the repo and open `Cuentas Claras/Cuentas Claras.xcodeproj`.
2. Select your own Apple ID as the signing team (Signing & Capabilities) to run on a physical device.
3. Build and run.

## Notes

- **MSAL is pinned to exactly 2.16.0** because the 2.16.1 release was published without its binary. Go back to a normal version rule (Up to Next Major) once a release ships with its binary.
- **Credit notes (spec section 7)** have no confirmed selectors, so they fall into `.unsupported` in v1 until a real case is available.

## Project structure

```
docs/                      Full spec and development process docs
Cuentas Claras/             Xcode project (app + unit tests)
```

## Development process

This project follows spec-driven development: the full technical spec lives in `docs/spec-invoice-scanner.md` and is written before implementation, section by section. Development is done with Claude Code, following the rules in `CLAUDE.md` at the repo root. Git workflow (branching, commit conventions, CI, releases) is documented in `docs/git-workflow.md`.

## License

TBD.
