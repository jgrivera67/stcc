# stC Language Support for VSCode

Language support for Strong-Typed C (stC) programming language.

## Features

- **Syntax Highlighting**: Full syntax highlighting for stC files
- **Error Diagnostics**: Real-time error checking using the stC compiler
- **Code Navigation**: Navigate to type and function declarations
- **Auto-completion**: Keyword and type completion
- **Bracket Matching**: Auto-closing brackets and quotes
- **Comment Toggle**: Line and block comment support

## Syntax Highlighting

The extension provides comprehensive syntax highlighting for:

- Keywords: `module`, `type`, `subtype`, `range`, `modular`, `struct`, `union`, `enum`
- Control flow: `if`, `else`, `while`, `for`, `switch`, `case`, `return`
- Contracts: `pre`, `post`, `invariant`, `assert`
- Parameter modes: `in`, `out`, `inout`
- Types: Built-in types and user-defined types ending in `_t`
- Literals: Numbers (decimal, hex, binary), strings, characters
- Operators: Arithmetic, logical, bitwise, comparison
- Comments: Line (`//`) and block (`/* */`) comments

## Language Server Features

### Error Diagnostics

The language server runs the stC compiler on your code and reports errors in real-time. Errors are highlighted with red squiggles and detailed messages.

### Code Navigation

- **Document Symbols**: View all types and functions in the current file
  - Press `Ctrl+Shift+O` (or `Cmd+Shift+O` on Mac) to see document outline
- Navigate through your code structure easily

### Auto-completion

Get intelligent suggestions for:
- Language keywords
- Built-in types
- Parameter modes
- Contract keywords
- Constants (`true`, `false`, `machine_width`)

## Requirements

The stC compiler (`stcc`) must be installed and available in your PATH, or you can configure a custom path in settings.

## Extension Settings

This extension contributes the following settings:

* `stc.compilerPath`: Path to the stC compiler (default: `stcc`)
* `stc.trace.server`: Enable trace logging for the language server

## Installation

### From Source

1. Clone the repository
2. Navigate to `vscode-stc-extension`
3. Run `npm install`
4. Run `npm run compile`
5. Press `F5` to launch the extension in development mode

### Building VSIX Package

```bash
cd vscode-stc-extension
npm install
npm run compile
npx vsce package
```

Then install the generated `.vsix` file in VSCode.

## stC Language Overview

stC (Strong-Typed C) is a systems programming language with:

- **Type Safety**: Range types and modular types with compile-time checking
- **Subtypes**: Ada-style subtypes for semantic type constraints
- **Contracts**: Pre/post conditions and invariants
- **Parameter Modes**: `in`, `out`, `inout` for clear parameter semantics
- **C Compatibility**: Familiar C-like syntax with safety improvements

### Example Code

```stc
module example {
  // Range type with explicit bounds
  type range 0 .. 255 byte_t;

  // Subtype constraining a base type
  type range -100 .. 100 temperature_t;
  subtype temperature_t range 0 .. 100 celsius_positive_t;

  // Modular type (unsigned with wraparound)
  type modular 256 uint8_t;
  type modular 1 << 32 uint32_t;

  // Function with contracts
  byte_t add(in byte_t a, in byte_t b)
    pre(a + b <= 255)
    post(result == a + b)
  {
    return a + b;
  }
}
```

## Release Notes

### 0.1.0

Initial release:
- Syntax highlighting for stC
- Language server with error diagnostics
- Code navigation (document symbols)
- Auto-completion for keywords and types
- Bracket matching and auto-closing

## Contributing

Contributions are welcome! Please visit the stC project repository.

## License

Apache-2.0
