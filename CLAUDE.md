# CLAUDE.md

Shared architecture and style rules live in the Copilot instructions and are imported below, so
both tools read the same source. Keep general project rules there; keep Claude Code workflow
details in this file.

@.github/copilot-instructions.md

## Repository layout

| Path                           | Project             | Target                | Notes                                                         |
| ------------------------------ | ------------------- | --------------------- | ------------------------------------------------------------- |
| `cli/Cli.csproj`               | `gdialog` CLI       | `net10.0`             | Packed as a .NET global tool                                  |
| `lang/Lang.csproj`             | interpreter library | `netstandard2.1`, C#9 | **git submodule** (`gamedialog/lang`)                         |
| `lang.tests/Lang.Tests.csproj` | xUnit tests         | `net10.0`             | Sees `internal` types via `InternalsVisibleTo`                |
| `docs/`                        | Docusaurus site     | Node                  | **git submodule** (`gamedialog/docs`); `npm start` to preview |

Solution file: `game-dialog-cli.slnx`.

## Commands

- Build everything: `dotnet build game-dialog-cli.slnx`
- Build the CLI only: `dotnet build cli/Cli.csproj`
- Run tests: `dotnet test lang.tests/Lang.Tests.csproj`
- Run a script: `dotnet run --project cli -- script.gds`
- Format one file: `dotnet format whitespace <project> --no-restore --include <file>`

`TreatWarningsAsErrors` and `EnforceCodeStyleInBuild` are enabled in every project, and
`.editorconfig` raises IDE0005 to an error — a single unused `using` fails the build.

There is no CI: `.github/` holds only `copilot-instructions.md`, and no workflows exist. Every check
runs locally, so build and test before declaring anything done.

`dotnet build game-dialog-cli.slnx` **rewrites the solution file and silently drops projects it cannot
resolve** — the build still reports success, it just builds less. After renaming or moving a project,
run `git diff game-dialog-cli.slnx` and restore it if entries disappeared.

## Local automation (`.claude/`)

`settings.json`, the hooks and the commands are committed on purpose; only `settings.local.json` is
personal (see the note in `.gitignore`).

- `hooks/format-cs.sh` (PostToolUse on Write|Edit) runs `dotnet format whitespace` against the nearest
  `.csproj` after **every** `.cs` edit. Do not hand-align whitespace, and expect the file on disk to
  differ slightly from what was just written.
- `hooks/submodule-status.sh` (SessionStart) injects `git submodule status` into the session context.
- `/check` (`commands/check.md`) — build the solution, then run the tests; stop on failure.
- `/release` (`commands/release.md`) — `dotnet pack` plus the `Homebrew` publish and `shasum` of the
  tarball. The Homebrew formula lives in a separate repository, `gamedialog/homebrew-tools`. The command
  never commits, tags or publishes unless asked.

## Submodules: check before committing

`lang/` and `docs/` are separate git repositories:

- `lang/` → `https://github.com/gamedialog/lang.git` — the interpreter; most code changes land here
- `docs/` → `https://github.com/gamedialog/docs.git`

Changes inside those directories do **not** belong to a commit in this repository. Commit inside the
submodule first, then commit the updated submodule pointer here. Staging a submodule directory in
this repo records only a new pointer, never the file changes.

## Stale docs to watch

The documentation lives in a submodule that is easy to forget, so it drifts. Remaining known-stale
spots:

- `lang/README.md` — still shows `dialog.Execute(script)` returning strings; the API is
  `RunInline` / `RunFile` returning `IEnumerable<RuntimeItem>`.
- root `README.md` — its example shows the `Variables:` block for a plain `gdialog script.gds`
  invocation, but that block only appears with `--vars` / `-v`. It also omits `--about`, `>>` and the
  exit codes.

`docs/` was rewritten against the implementation (`docs/docs/language/*`, `errors.md`, `cli.md`,
`limitations.md`, `quick-start.md`; the stale `syntax.md` is gone). When changing syntax, semantics or
the CLI surface, update the matching page there — and note the convention that **every example is a
runnable script with its real output**, which is what kept the old `syntax.md` from being verifiable.
`docs/docs/limitations.md` doubles as the list of known defects (broken escape sequences, `#` and
blank lines inside strings, CRLF, lax CLI argument parsing); fix one and remove its section.

To check the site: `cd docs && npm ci && npm run build` — `onBrokenLinks` is `throw`, and broken
heading anchors are reported as warnings, so read the build output rather than only its exit code.

## Conversation language

Reply to the maintainer in Russian. Code, comments, commit messages, documentation and identifiers
stay in English, per the imported instructions.
