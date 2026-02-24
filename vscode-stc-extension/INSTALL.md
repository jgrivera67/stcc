# Installation Instructions for stC VSCode Extension

## Prerequisites

1. **Node.js and npm**: Install from https://nodejs.org/ (version 18 or higher recommended)
2. **stC Compiler**: The `stcc` compiler must be built and accessible in your PATH

## Installation Steps

### Option 1: Install from VSIX (Recommended)

1. Build the VSIX package:
   ```bash
   cd vscode-stc-extension
   npm install
   npm run compile
   npx @vscode/vsce package
   ```

2. Install in VSCode:
   - Open VSCode
   - Go to Extensions view (Ctrl+Shift+X)
   - Click the "..." menu at the top
   - Select "Install from VSIX..."
   - Choose the generated `stc-language-*.vsix` file

### Option 2: Development Mode

For development and testing:

1. Install dependencies:
   ```bash
   cd vscode-stc-extension
   npm install
   ```

2. Compile the extension:
   ```bash
   npm run compile
   ```

3. Open in VSCode:
   ```bash
   code .
   ```

4. Press `F5` to launch the Extension Development Host

### Option 3: Link for Development

1. Build the extension:
   ```bash
   cd vscode-stc-extension
   npm install
   npm run compile
   ```

2. Create a symlink to the extension directory:
   - **Linux/Mac**:
     ```bash
     ln -s $(pwd) ~/.vscode/extensions/stc-language-0.1.0
     ```
   - **Windows** (PowerShell as Administrator):
     ```powershell
     New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.vscode\extensions\stc-language-0.1.0" -Target "$(Get-Location)"
     ```

3. Restart VSCode

## Configuration

After installation, you may need to configure the stC compiler path:

1. Open VSCode Settings (Ctrl+,)
2. Search for "stc"
3. Set `stc.compilerPath` to the full path of your stcc compiler

For example:
```json
{
  "stc.compilerPath": "/home/username/my-projects/stcc/bin/stcc"
}
```

Or if stcc is in your PATH:
```json
{
  "stc.compilerPath": "stcc"
}
```

## Verifying Installation

1. Create a new file with `.stc` extension
2. Type `module` and verify that syntax highlighting appears
3. Type `type ` and verify that auto-completion suggestions appear
4. Save a file with errors and verify that red squiggles appear

## Troubleshooting

### Extension not loading

- Check the Output panel (View → Output) and select "stC Language Server" from the dropdown
- Verify that the extension is enabled in Extensions view

### No syntax highlighting

- Verify the file has `.stc` extension
- Reload the window (Ctrl+Shift+P → "Reload Window")

### No error diagnostics

- Verify `stc.compilerPath` is set correctly
- Test the compiler manually: `stcc yourfile.stc`
- Check the stC Language Server output panel for errors

### Compiler not found

If you see errors about the compiler not being found:

1. Make sure `stcc` is built:
   ```bash
   cd /path/to/stcc
   alr build
   ```

2. Either add it to PATH or set the full path in settings:
   ```bash
   export PATH="/path/to/stcc/bin:$PATH"
   ```

## Uninstalling

- From VSCode: Go to Extensions view, find "stC Language Support", click the gear icon, and select "Uninstall"
- Manual: Remove the extension directory from `~/.vscode/extensions/`

## Development Watch Mode

For continuous development:

```bash
cd vscode-stc-extension
npm run watch
```

This will automatically recompile when you make changes to the TypeScript files.
