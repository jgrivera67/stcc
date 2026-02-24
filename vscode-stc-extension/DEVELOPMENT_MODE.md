# Using stC Extension in Development Mode

If the installed extension isn't working, use Development Mode instead.
This bypasses all installation issues and loads the extension directly.

## Quick Start (2 minutes)

### Step 1: Open Extension Folder in VSCode

```bash
code /home/josegrivera/my-projects/stcc/vscode-stc-extension
```

Or in VSCode:
- File → Open Folder
- Navigate to: `/home/josegrivera/my-projects/stcc/vscode-stc-extension`
- Click "Open"

### Step 2: Press F5

Just press **F5** (or Run → Start Debugging)

A **NEW VSCode window** opens with `[Extension Development Host]` in the title.

### Step 3: Open Your .stc Files in the NEW Window

In the Extension Development Host window:
- File → Open Folder → `/home/josegrivera/my-projects/stcc`
- Open any `.stc` file (e.g., `stc-code/basic_types.stc`)

## Features Now Work!

In the Extension Development Host window:

✅ **Syntax Highlighting** - Keywords are colored
✅ **Go to Definition** - Ctrl+Click on `uint32_t` → jumps to definition
✅ **Document Outline** - Press `Ctrl+Shift+O` to see all types/functions
✅ **Auto-completion** - Type `type ` and see suggestions
✅ **Error Diagnostics** - Save file to see compiler errors

## Debugging

While the extension runs:
- Set breakpoints in `client/src/extension.ts` or `server/src/server.ts`
- View → Output → "stC Language Server" to see server logs
- Check "Extension Host" output for errors

## Stopping

To stop the Extension Development Host:
- Close the `[Extension Development Host]` window
- Or press Shift+F5 in the main window

## Making Changes

If you modify the extension code:
1. Save your changes
2. Press `Ctrl+Shift+P` in the Development Host window
3. Type: "Developer: Reload Window"
4. Or just close it and press F5 again

## Why Use This?

Development Mode:
- ✅ Bypasses symlink installation issues
- ✅ Always uses latest compiled code
- ✅ Provides full debugging capabilities
- ✅ Works even if normal installation fails
- ✅ Isolated from main VSCode (no conflicts)

## Making It Permanent

Once you verify everything works in Development Mode, you can package
the extension properly:

```bash
cd vscode-stc-extension
npx @vscode/vsce package --allow-missing-repository
```

This creates a `.vsix` file you can install:
- Ctrl+Shift+X → "..." → Install from VSIX
