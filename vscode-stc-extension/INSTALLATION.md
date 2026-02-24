# Installing the stC VSCode Extension

## Quick Install (Recommended)

The extension is packaged as `stc-language-0.1.0.vsix` and ready to install.

### Method 1: Install via VSCode UI

1. Open VSCode
2. Press `Ctrl+Shift+X` (Extensions view)
3. Click the `...` menu (three dots) at the top
4. Select **"Install from VSIX..."**
5. Navigate to this folder and select `stc-language-0.1.0.vsix`
6. Click **"Install"**
7. Reload VSCode when prompted

### Method 2: Install via Command Line

```bash
code --install-extension /path/to/stc-language-0.1.0.vsix
```

Then reload VSCode.

## Verify Installation

1. Press `Ctrl+Shift+X` (Extensions)
2. Search for "stC"
3. You should see **"stC Language Support v0.1.0"** with status "Installed"

## Test the Extension

1. Open any `.stc` file (e.g., `../stc-code/basic_types.stc`)
2. **Syntax highlighting** - Keywords should be colored
3. **Go to Definition** - Ctrl+Click on `uint32_t` → jumps to definition
4. **Document Outline** - Press `Ctrl+Shift+O` → see all types/functions
5. **Auto-completion** - Type `type ` → see suggestions

## Configuration

Set the compiler path in VSCode settings:

1. Press `Ctrl+,` (Settings)
2. Search for "stc compiler"
3. Set **stC: Compiler Path** to your `stcc` binary location:
   ```
   /path/to/stcc/bin/stcc
   ```

Or edit `settings.json`:
```json
{
  "stc.compilerPath": "/home/yourusername/my-projects/stcc/bin/stcc"
}
```

## Features

✅ **Syntax Highlighting** - Full TextMate grammar for stC
✅ **Go to Definition** - F12 or Ctrl+Click on types/functions
✅ **Document Symbols** - Ctrl+Shift+O for outline view
✅ **Auto-completion** - Smart keyword and type suggestions
✅ **Error Diagnostics** - Real-time compiler error checking
✅ **Bracket Matching** - Auto-closing brackets and quotes
✅ **Comment Toggle** - Line and block comment support

## Uninstalling

To uninstall:
1. Press `Ctrl+Shift+X`
2. Find "stC Language Support"
3. Click the gear icon → "Uninstall"

## Development Mode (Alternative)

If you want to develop or debug the extension:

1. Open this folder in VSCode
2. Press `F5`
3. Use the extension in the new "[Extension Development Host]" window

See [DEVELOPMENT_MODE.md](DEVELOPMENT_MODE.md) for details.

## Troubleshooting

### Extension not appearing
- Make sure you reloaded VSCode after installation
- Check Extensions view (Ctrl+Shift+X) for "stC Language Support"

### Go to Definition not working
- Check Output panel: View → Output → "stC Language Server"
- Ensure compiler path is set correctly in settings
- Try reloading: Ctrl+Shift+P → "Reload Window"

### No syntax highlighting
- Verify file has `.stc` extension
- Try reloading window

For more help, see [QUICKSTART.md](QUICKSTART.md).
