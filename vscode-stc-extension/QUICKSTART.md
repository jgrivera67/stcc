# Quick Start Guide for stC VSCode Extension

This guide will get you up and running with the stC VSCode extension in a few minutes.

## Prerequisites

- **Node.js** (v18 or higher): Download from https://nodejs.org/
- **VSCode**: Download from https://code.visualstudio.com/
- **stC Compiler**: Built from the stcc project

## Quick Installation

### Step 1: Build the Extension

```bash
cd vscode-stc-extension
npm install
npm run compile
```

This installs dependencies and compiles TypeScript to JavaScript.

### Step 2: Install in VSCode

#### Option A: Use F5 (Development Mode)

1. Open the `vscode-stc-extension` folder in VSCode:
   ```bash
   code vscode-stc-extension
   ```

2. Press `F5` to launch Extension Development Host

3. A new VSCode window opens with the extension loaded

#### Option B: Build and Install VSIX

```bash
npm install -g @vscode/vsce
vsce package
```

This creates `stc-language-*.vsix`. Then:
1. Open VSCode
2. Press `Ctrl+Shift+X` (Extensions view)
3. Click `...` → Install from VSIX
4. Select the `.vsix` file

### Step 3: Configure Compiler Path

1. Open VSCode Settings (`Ctrl+,`)
2. Search for "stc"
3. Set **stc.compilerPath** to your stcc location:
   ```
   /home/yourusername/my-projects/stcc/bin/stcc
   ```

## Try It Out

1. Create a new file `test.stc`

2. Type this code:
```stc
module test {
  type range 0 .. 255 byte_t;
  
  byte_t add(in byte_t a, in byte_t b) {
    return a + b;
  }
}
```

3. **See it in action:**
   - ✅ Syntax highlighting appears
   - ✅ Type `type ` and see auto-completion
   - ✅ Save the file and see errors (if any) underlined
   - ✅ Press `Ctrl+Shift+O` to see document outline

## Features Demo

### 1. Syntax Highlighting

Keywords are colored differently:
- **Purple**: `module`, `type`, `subtype`, `range`
- **Blue**: `if`, `while`, `for`, `return`
- **Green**: Comments
- **Orange**: Strings and numbers

### 2. Error Diagnostics

Add an error:
```stc
type range 0 .. 255 byte_t  // Missing semicolon!
```

You'll see a red squiggle and error message.

### 3. Code Navigation

Press `Ctrl+Shift+O` to see:
- All types defined in the file
- All functions defined in the file

Click any item to jump to its definition.

### 4. Auto-Completion

Type these and see suggestions:
- `mod` → suggests `module`, `modular`
- `type ` → suggests `range`, `modular`, `struct`, `enum`
- `sub` → suggests `subtype`

## Common Issues

### Extension Not Loading

**Check Output Panel:**
1. View → Output
2. Select "stC Language Server" from dropdown
3. Look for errors

**Solution:** Make sure you ran `npm install` and `npm run compile`

### No Syntax Highlighting

**Check File Extension:**
- File must end with `.stc`

**Reload Window:**
- Press `Ctrl+Shift+P` → "Developer: Reload Window"

### Compiler Not Found

**Error:** "stcc: command not found"

**Solutions:**
1. **Set full path in settings:**
   ```json
   {
     "stc.compilerPath": "/full/path/to/stcc/bin/stcc"
   }
   ```

2. **Or add to PATH:**
   ```bash
   export PATH="/path/to/stcc/bin:$PATH"
   ```

3. **Verify it works:**
   ```bash
   /path/to/stcc/bin/stcc --version  # Should run without error
   ```

## Development Workflow

### Watch Mode for Development

If you're modifying the extension:

```bash
npm run watch
```

This automatically recompiles when you change `.ts` files.

Then press `F5` in VSCode to test changes.

### Debug Both Client and Server

1. Set breakpoints in `client/src/extension.ts` or `server/src/server.ts`
2. Press `F5` → Select "Client + Server"
3. Breakpoints will trigger when extension runs

## Next Steps

- Read [README.md](README.md) for complete feature list
- See [examples/example.stc](examples/example.stc) for syntax examples
- Check [INSTALL.md](INSTALL.md) for detailed installation options

## Support

For issues or questions:
- Check the Language Server output panel
- Verify stcc works from command line
- Review settings: `Ctrl+,` → search "stc"

Enjoy coding in stC! 🚀
