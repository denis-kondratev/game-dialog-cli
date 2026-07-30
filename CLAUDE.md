# CLAUDE.md

Shared architecture and style rules live in the Copilot instructions and are imported below, so
both tools read the same source. Keep general project rules there; keep Claude Code workflow
details in this file.

@.github/copilot-instructions.md

## Repository layout

| Path                          | Project             | Target                | Notes                                    |
| ----------------------------- | ------------------- | --------------------- | ---------------------------------------- |
| `cli/Cli.csproj`              | `gdialog` CLI       | `net10.0`             | Packed as a .NET global tool             |
| `lang/Lang.csproj`            | interpreter library | `netstandard2.1`, C#9 | **git submodule** (`gamedialog/lang`)    |
| `lang.tests/Lang.Tests.csproj` | xUnit tests        | `net10.0`             | Sees `internal` types via `InternalsVisibleTo` |

Solution file: `game-dialog-cli.slnx`.

## Commands

- Build everything: `dotnet build game-dialog-cli.slnx`
- Build the CLI only: `dotnet build cli/Cli.csproj`
- Run tests: `dotnet test lang.tests/Lang.Tests.csproj`
- Run a script: `dotnet run --project cli -- script.gds`
- Format one file: `dotnet format whitespace <project> --no-restore --include <file>`

`TreatWarningsAsErrors` and `EnforceCodeStyleInBuild` are enabled in every project, and
`.editorconfig` raises IDE0005 to an error — a single unused `using` fails the build.

## Submodules: check before committing

`lang/` and `docs/` are separate git repositories:

- `lang/` → `https://github.com/gamedialog/lang.git` — the interpreter; most code changes land here
- `docs/` → `https://github.com/gamedialog/docs.git`

Changes inside those directories do **not** belong to a commit in this repository. Commit inside the
submodule first, then commit the updated submodule pointer here. Staging a submodule directory in
this repo records only a new pointer, never the file changes.

## Verified facts about the current code

The imported Copilot instructions are partly stale. Where they disagree with this section, this
section is correct:

- Namespace is `GameDialog.Lang`, not `BitPatch.DialogLang`.
- Public surface is `Dialog` with `RunInline(string)`, `RunFile(string)` and `Variables`; both run
  methods yield `RuntimeItem` values.
- CLI script execution lives in `cli/ScriptRunner.cs`; there is no `ScriptExecutor.cs`.
- Test helpers are `Utils.Execute(script)`, `Utils.Parse()` and `Utils.Tokenize()` in
  `lang.tests/TestUtils.cs`.

## Known issue: csproj filename case

Git tracks `cli/cli.csproj` and `lang.tests/lang.tests.csproj` in lowercase, while the working tree
and `game-dialog-cli.slnx` reference `Cli.csproj` and `Lang.Tests.csproj`. This only resolves
because macOS is case-insensitive; a case-sensitive checkout (Linux CI) cannot restore the
solution. Fix with `git mv --force` before adding CI.

## Conversation language

Reply to the maintainer in Russian. Code, comments, commit messages, documentation and identifiers
stay in English, per the imported instructions.
