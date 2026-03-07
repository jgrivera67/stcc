import * as path from 'path';
import { workspace, ExtensionContext } from 'vscode';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: ExtensionContext) {
  console.log('stC extension is now activating!');

  // The server is implemented in node
  const serverModule = context.asAbsolutePath(
    path.join('server', 'out', 'server.js')
  );

  console.log('Server module path:', serverModule);

  // If the extension is launched in debug mode then the debug server options are used
  // Otherwise the run options are used
  const serverOptions: ServerOptions = {
    run: { module: serverModule, transport: TransportKind.ipc },
    debug: {
      module: serverModule,
      transport: TransportKind.ipc,
      options: { execArgv: ['--nolazy', '--inspect=6009'] }
    }
  };

  // Options to control the language client
  const clientOptions: LanguageClientOptions = {
    // Register the server for stC documents
    documentSelector: [{ scheme: 'file', language: 'stc' }],
    synchronize: {
      // Notify the server about file changes to '.stc files contained in the workspace
      fileEvents: workspace.createFileSystemWatcher('**/*.stc')
    }
  };

  // Create the language client and start the client.
  client = new LanguageClient(
    'stcLanguageServer',
    'stC Language Server',
    serverOptions,
    clientOptions
  );

  console.log('Starting Language Client...');

  // Start the client. This will also launch the server
  client.start().then(() => {
    console.log('stC Language Client started successfully!');
  }).catch((error: any) => {
    console.error('Failed to start stC Language Client:', error);
  });
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
