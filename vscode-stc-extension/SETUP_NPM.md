# Setting Up npm for the stC VSCode Extension

## Problem

You have Node.js installed but npm is missing. This can happen with certain Node.js installation methods.

## Solution

Install Node.js and npm from NodeSource (recommended):

```bash
# Download and run the NodeSource setup script
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# Install Node.js (includes npm)
sudo apt-get install -y nodejs

# Verify installation
node --version  # Should show v20.x.x
npm --version   # Should show 10.x.x or higher
```

## Alternative: Use nvm (Node Version Manager)

If you don't have sudo access or prefer nvm:

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Reload your shell configuration
source ~/.bashrc  # or source ~/.zshrc

# Install Node.js LTS (includes npm)
nvm install --lts
nvm use --lts

# Verify
node --version
npm --version
```

## After Installing npm

Once npm is available, build the extension:

```bash
cd vscode-stc-extension

# Install dependencies
npm install

# Compile TypeScript to JavaScript
npm run compile

# Test the extension
code .
# Press F5 to launch Extension Development Host
```

## Verification

Check that everything is installed:

```bash
which node    # Should show path like /usr/bin/node
which npm     # Should show path like /usr/bin/npm
node --version
npm --version
```

## Troubleshooting

### npm install fails with permission errors

If you see EACCES errors:

```bash
# Fix npm permissions (run once)
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

### Node version too old

The extension requires Node.js 18 or higher. Update using NodeSource or nvm as shown above.

### npm command not found after installation

Reload your shell:

```bash
source ~/.bashrc
# or restart your terminal
```
