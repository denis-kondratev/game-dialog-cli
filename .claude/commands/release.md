---
description: Build gdialog release artifacts (NuGet global tool + Homebrew ARM64 tarball)
argument-hint: [version, e.g. 0.2.0]
---

# Release

Prepare release artifacts for version `$1`. If `$1` is empty, ask me for the version before doing
anything.

1. Verify the working tree is clean, including submodules (`git status`, `git submodule status`).
   Stop and tell me if it is not.
2. Set `<Version>` in `cli/Cli.csproj` to `$1`.
3. `dotnet test lang.tests/Lang.Tests.csproj` — stop on any failure.
4. NuGet global tool package: `dotnet pack cli/Cli.csproj -c Release`.
5. Homebrew artifact: `dotnet publish cli/Cli.csproj -c Homebrew`. The `CreateHomebrewTar` MSBuild
   target writes `cli/gdialog-$1-osx-arm64.tar.gz`.
6. Print `shasum -a 256` of that tarball — the formula in `gamedialog/homebrew-tools` needs it.
7. Summarize the produced artifacts with their paths and the sha256.

Do not commit, tag, push, or publish to NuGet unless I explicitly ask.
