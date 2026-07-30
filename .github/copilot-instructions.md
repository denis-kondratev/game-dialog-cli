# GitHub Copilot Instructions

## Language Guidelines

- **All commit messages must be written in English**
- **All code comments must be written in English**
- This ensures consistency and maintainability across the codebase for all contributors

## Project Overview

This repository contains the **Game Dialog Script Language** - a simple language for writing game dialogs with integrated logic. The project consists of:

### lang (Core Library)

The main interpreter implementation for Game Dialog Script Language (.gds files). Lives in the `lang/`
**git submodule** (`gamedialog/lang`), so most language changes are committed there, not in this
repository.

- **Namespaces**: `GameDialog.Lang`, plus `GameDialog.Lang.Ast` and `GameDialog.Lang.Diagnostic`
- **Target Framework**: `netstandard2.1` (for Unity and Godot compatibility)
- **C# Version**: 9.0
- **Architecture**: Three-stage streaming pipeline: `Lexer → Parser → Interpreter`
- **Public API**:
  - `Dialog` - entry point: `RunInline(string)`, `RunFile(string)`, `Variables`
  - `RuntimeItem` (abstract) → `RuntimeValue` → `RuntimeNumber` → `RuntimeInteger` / `RuntimeFloat`,
    plus `RuntimeString` and `RuntimeBoolean` (`RuntimeValues.cs`)
  - `RuntimeRequest<TOutput, TInput>` → `RuntimeValueRequest` (`RuntimeRequests.cs`) - host input
  - `ScriptError` (abstract) → `SyntaxError` / `RuntimeError`, and `LogUtils` for rendering them
  - `SourceType`
- **Internal implementation**:
  - `Lexer` - tokenizes source code; a push-down state machine over `StateStack` / `LexerState`
    (`Default`, `ReadingString`, `ReadingMultiString`, `ReadingInlineExpression`)
  - `Reader` - char-level reader beneath the lexer; owns line/column tracking and skips `#` comments
  - `Indenter` / `IndenterState` - emits `Indent` / `Dedent` tokens from a stack of indent levels;
    `Locking()` suspends this so a multi-line string body does not open blocks
  - `Parser` - builds AST from tokens
  - `Interpreter` - executes AST statements
  - `Source` / `Location` / `Loop` - source origin, span tracking, loop guard
  - `Ast.Nodes` - AST node definitions using C# records
- **Do not delete `IsExternalInit.cs`** - it is the polyfill that makes C# 9 records compile on
  netstandard2.1
- **Unity Integration**: Includes `GameDialogScript.asmdef` for Unity compatibility

### cli (CLI Tool)

Command-line tool for running .gds script files.

- **Command**: `gdialog script.gds`
- **Namespace**: `GameDialog.Cli`
- **Target Framework**: `net10.0`
- **Package**: Published as .NET global tool (`gdialog`)
- **Distribution**: NuGet global tool + Homebrew (with special `Homebrew` build configuration)
- **Key Files**:
  - `Program.cs` - Minimal entry point using switch expressions
  - `ScriptRunner.cs` - Script execution with detailed error reporting
  - `CommandLineOptions.cs` - CLI argument parsing
  - `TypeParser.cs` - parses console input for `>>`: int, then float, then trimmed string
    (**booleans are not parsed** - typing `true` yields the string `"true"`)

### lang.tests

Unit tests for the interpreter using xUnit, with `Utils.Execute()` helper for streamlined testing.

## Architecture Guidelines

### Streaming Architecture

All three stages (Lexer, Parser, Interpreter) MUST operate in streaming mode:

- Data flows through pipeline using `IEnumerable<T>` and `yield return`
- **No buffering** - process tokens, AST nodes, and dialog lines incrementally
- Example: `Dialog.RunInline` / `RunFile` build a `Source`, then stream
  `Lexer.Tokenize() → Parser.Parse() → Interpreter.Execute()`, yielding `RuntimeItem` values
- Each stage yields items one by one (tokens, statements, output values)
- This enables processing large scripts without loading everything into memory
- Consequence: results are lazy. `Dialog.Variables` stays empty until the returned sequence is drained

### Error Handling Pattern

- `ScriptError : Exception` base class with `Location` tracking (line/column info)
- Specific error types: `SyntaxError`, `RuntimeError`
- CLI shows errors with source context: line highlighting and column markers
- Use the public `LogUtils.FormatError(ScriptError, indent)` for user-friendly error display, as
  `cli/ScriptRunner.cs` does. File-backed sources are re-opened to render the offending line

### Nullable Reference Types

- **TreatWarningsAsErrors** is enabled - all nullable warnings are compilation errors
- **Internal/private classes and methods**: Do NOT add null checks for non-nullable parameters - the compiler enforces null safety at compile time
- **Public API classes and methods** (including public constructors and methods of internal classes): ALWAYS add explicit null checks with `ArgumentNullException` for non-nullable parameters, as external consumers may have different nullable settings or use reflection

### AST Design

- All AST nodes are `internal` C# records inheriting from `Node(Location)`
- Two main categories: `Statement` (executed) and `Expression` (evaluated)
- There is no marker interface for conditionals. Conditions are resolved with
  `Evaluate<RuntimeBoolean>(...)`, which throws on any other type - **the language has no truthiness**
- `Ast.Identifier` derives from `Node` and names an assignment target; reading a variable is
  `Ast.Variable`. An interpolated string is `Ast.String(IReadOnlyList<Expression> Parts)`, while a plain
  literal chunk is `Ast.InlineString`
- `Ast.Program` exists but is unused - `Parser.Parse()` yields statements directly
- The interpreter is **not recursive**: `Interpreter.Execute` drives an explicit `Stack<Statement>`
  (plus a `Stack<Loop>`), and `while` re-pushes itself before its body. Adding a statement type means
  adding a `case` to that loop, not writing a visitor

### Language Features

The Game Dialog Script Language supports:

- **Variables**: Assignment and usage (`name = "Arthur"`)
- **Output**: Dialog lines (`<< "Hello!"`)
- **Input**: `>> name` yields a `RuntimeValueRequest`; the host calls `request.Request(value)` and
  execution resumes with the value stored in the variable
- **String concatenation**: (`"Hello, " + name + "!"`)
- **String interpolation**: (`"Hello, {name}!"`, `"{10 + 5}"`) - a nested `{` inside the expression is an error
- **Multi-line strings**: three or more quotes (`"""..."""`, `""""..."""" `); the closing run must match
  the opening count exactly, which is how a literal `"""` can sit inside a `""""` string
- **Arithmetic**: `+`, `-`, `*`, `/`, `%`, and unary `-`
- **Comparisons**: `==`, `!=`, `<`, `>`, `<=`, `>=`
- **Boolean logic**: `and`, `or`, `xor`, `not`, `true`, `false`
- **Control flow**: `if` / `else if` / `else` (there is no `elif` keyword), `while` loops
- **Indentation-based blocks**: Spaces or tabs (consistent style enforced)
- **Comments**: `#` to end of line (handled by `Reader`, before the lexer sees it)
- **Grouping**: parentheses

Semantics worth knowing before reporting a bug:

- **`while` is capped at 100 iterations** (`Interpreter(int maxLoopIterations = 100)`), and `Dialog` does
  not expose a way to raise it - a longer legitimate loop fails with `RuntimeError`
- `/` always yields `RuntimeFloat`; `+` yields `RuntimeInteger` only for int + int; `+` with a string on
  either side concatenates
- Division or `%` by zero raises `RuntimeError`
- Comparisons `<`, `>`, `<=`, `>=` are numeric-only; `==` and `!=` compare across types
- A `Dialog` instance keeps one interpreter, so **variables persist across `RunInline` / `RunFile` calls**
- `break` and `continue` are lexed into tokens but not implemented in the parser - they are reserved
  words that cannot be used as identifiers and cannot be used as statements
- Single-quoted strings are **not** supported, despite what `docs/` currently says

## Development Workflows

### Building and Testing

- **Build**: Use VS Code's default build task or `dotnet build game-dialog-cli.slnx`
- **Tests**: Run all tests with `dotnet test lang.tests/Lang.Tests.csproj`
- **Local Testing**: Use `Utils.Execute("script")` in tests for quick execution
- **CLI Testing**: Build then run `dotnet run --project cli -- script.gds`

### Distribution Builds

- **NuGet Global Tool**: Standard `Release` configuration publishes to NuGet
- **Homebrew**: Special `Homebrew` configuration creates self-contained ARM64 binary
  - Uses `RuntimeIdentifier=osx-arm64` and `PublishSingleFile=true`
  - Automatically creates `.tar.gz` archive via MSBuild target
- Both disable debug symbols (`DebugType=none`) for smaller packages
- The `Homebrew` configuration is declared in **both** `cli/Cli.csproj` and `lang/Lang.csproj`; a new
  project needs the same `PropertyGroup` or that configuration will not build

### Testing Patterns

- Use `Utils.Execute()` helper: `var output = Utils.Execute("x = 1\n<< x");` - returns `List<RuntimeItem>`
- `Parse()` and `Tokenize()` are **extension methods on `string`**, so they read `script.Parse()` and
  `script.Tokenize()`; `Tokenize()` returns `TokenType[]`, not tokens
- Assert with the `List<RuntimeItem>` extensions in `TestUtils.cs`: `AssertEqual` (`int`, `float`,
  `string`, `bool`, `params object[]`), `AssertTrue`, `AssertFalse`; for errors use
  `AssertLocation(line, initial, final)`; for AST shape use `AddTypesTo`
- `TokenSequence : IXunitSerializable` exists so arrays of the internal `TokenType` enum can travel
  through xUnit theory data
- To test `>>`, use the local `ExecuteWithInput` helpers in `InputTests.cs`, which pump
  `RuntimeValueRequest` values back into the interpreter
- Tests reach internal types through `<InternalsVisibleTo Include="Lang.Tests" />` in `lang/Lang.csproj`,
  so the test assembly must stay named `Lang.Tests`
- Test files typically verify both output and final variable state
- Follow pattern: Arrange (script string) → Act (Execute) → Assert (output + variables)

## Code Style

- Follow C# naming conventions
- All internal types and implementation details should be `internal`
- Public API surface is minimal: `Dialog` plus the runtime value, request and error types listed above
- Keep code clean and well-documented with XML comments
- Write meaningful variable and function names
- Use explicit types for clarity where appropriate

### Different language levels per project

The most common cause of a failed first build - the projects are not on the same C# version:

- `lang/` is netstandard2.1 / C# 9 with **no `ImplicitUsings`**: block-scoped namespaces, explicit
  `using` directives, no file-scoped namespaces, no collection expressions
- `cli/` and `lang.tests/` are net10.0 with `ImplicitUsings` enabled
- `GenerateDocumentationFile` is on in all three projects and CS1591 is suppressed only in
  `lang.tests`, so every new public or internal member in `lang/` and `cli/` needs an XML doc comment
- With `TreatWarningsAsErrors` and `EnforceCodeStyleInBuild` there is no soft landing: a single unused
  `using` (IDE0005 is an error in `.editorconfig`) or missing doc comment fails the build
