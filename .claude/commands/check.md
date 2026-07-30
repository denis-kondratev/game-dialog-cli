---
description: Build the solution and run all tests, then report the result
allowed-tools: Bash(dotnet build:*), Bash(dotnet test:*)
---

# Check

Build and test this repository, then report what happened.

1. `dotnet build game-dialog-cli.slnx`
2. `dotnet test lang.tests/Lang.Tests.csproj`

`TreatWarningsAsErrors` is on, so any warning is a build failure. If a step fails, show the failing
output verbatim with the file and line, and stop — do not fix anything unless I ask.
