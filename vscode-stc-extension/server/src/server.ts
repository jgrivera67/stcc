import {
  createConnection,
  TextDocuments,
  Diagnostic,
  DiagnosticSeverity,
  ProposedFeatures,
  InitializeParams,
  DidChangeConfigurationNotification,
  CompletionItem,
  CompletionItemKind,
  TextDocumentPositionParams,
  TextDocumentSyncKind,
  InitializeResult,
  DocumentSymbolParams,
  SymbolInformation,
  SymbolKind,
  Location,
  Range,
  Position
} from 'vscode-languageserver/node';

import { TextDocument } from 'vscode-languageserver-textdocument';
import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

// Create a connection for the server
const connection = createConnection(ProposedFeatures.all);

connection.console.log('stC Language Server starting...');

// Create a simple text document manager
const documents: TextDocuments<TextDocument> = new TextDocuments(TextDocument);

let hasConfigurationCapability = false;
let hasWorkspaceFolderCapability = false;
let hasDiagnosticRelatedInformationCapability = false;

connection.onInitialize((params: InitializeParams) => {
  const capabilities = params.capabilities;

  // Does the client support the `workspace/configuration` request?
  hasConfigurationCapability = !!(
    capabilities.workspace && !!capabilities.workspace.configuration
  );
  hasWorkspaceFolderCapability = !!(
    capabilities.workspace && !!capabilities.workspace.workspaceFolders
  );
  hasDiagnosticRelatedInformationCapability = !!(
    capabilities.textDocument &&
    capabilities.textDocument.publishDiagnostics &&
    capabilities.textDocument.publishDiagnostics.relatedInformation
  );

  const result: InitializeResult = {
    capabilities: {
      textDocumentSync: TextDocumentSyncKind.Incremental,
      completionProvider: {
        resolveProvider: true
      },
      documentSymbolProvider: true,
      definitionProvider: true
    }
  };
  if (hasWorkspaceFolderCapability) {
    result.capabilities.workspace = {
      workspaceFolders: {
        supported: true
      }
    };
  }
  return result;
});

connection.onInitialized(() => {
  if (hasConfigurationCapability) {
    // Register for all configuration changes.
    connection.client.register(DidChangeConfigurationNotification.type, undefined);
  }
  if (hasWorkspaceFolderCapability) {
    connection.workspace.onDidChangeWorkspaceFolders(_event => {
      connection.console.log('Workspace folder change event received.');
    });
  }
});

// The stC compiler settings
interface StcSettings {
  compilerPath: string;
  validationMode: 'realtime' | 'onSave';
  validationDelay: number;
}

// The global settings, used when the `workspace/configuration` request is not supported by the client.
const defaultSettings: StcSettings = {
  compilerPath: 'stcc',
  validationMode: 'realtime',
  validationDelay: 500
};
let globalSettings: StcSettings = defaultSettings;

// Cache the settings of all open documents
const documentSettings: Map<string, Thenable<StcSettings>> = new Map();

// Track debounce timeouts for each document (for realtime validation)
const validationTimeouts: Map<string, NodeJS.Timeout> = new Map();

connection.onDidChangeConfiguration(change => {
  if (hasConfigurationCapability) {
    // Reset all cached document settings
    documentSettings.clear();
  } else {
    globalSettings = <StcSettings>(
      (change.settings.stc || defaultSettings)
    );
  }

  // Revalidate all open text documents
  documents.all().forEach(validateTextDocument);
});

function getDocumentSettings(resource: string): Thenable<StcSettings> {
  if (!hasConfigurationCapability) {
    return Promise.resolve(globalSettings);
  }
  let result = documentSettings.get(resource);
  if (!result) {
    result = connection.workspace.getConfiguration({
      scopeUri: resource,
      section: 'stc'
    });
    documentSettings.set(resource, result);
  }
  return result;
}

// Only keep settings for open documents
documents.onDidClose(e => {
  documentSettings.delete(e.document.uri);

  // Clear any pending validation timeout
  const timeout = validationTimeouts.get(e.document.uri);
  if (timeout) {
    clearTimeout(timeout);
    validationTimeouts.delete(e.document.uri);
  }
});

// The content of a text document has changed. This event is emitted
// when the text document first opened or when its content has changed.
documents.onDidChangeContent(async (change) => {
  const settings = await getDocumentSettings(change.document.uri);

  if (settings.validationMode === 'realtime') {
    // Clear any existing timeout for this document
    const existingTimeout = validationTimeouts.get(change.document.uri);
    if (existingTimeout) {
      clearTimeout(existingTimeout);
    }

    // Set a new timeout to validate after the delay
    const timeout = setTimeout(() => {
      validateTextDocument(change.document);
      validationTimeouts.delete(change.document.uri);
    }, settings.validationDelay);

    validationTimeouts.set(change.document.uri, timeout);
  }
  // If mode is 'onSave', we don't validate on content change
});

// Validate when document is saved (for both modes)
documents.onDidSave(change => {
  validateTextDocument(change.document);
});

// Validate when document is first opened (for both modes)
documents.onDidOpen(change => {
  validateTextDocument(change.document);
});

async function validateTextDocument(textDocument: TextDocument): Promise<void> {
  // Get the stC compiler path from settings
  const settings = await getDocumentSettings(textDocument.uri);

  const diagnostics: Diagnostic[] = [];

  // Run the stC compiler on the file
  // Use a temporary file to validate current editor content (not just saved file)
  let tempFilePath: string | null = null;
  try {
    // Write current document content to a temporary file
    const originalPath = textDocument.uri.replace(/^file:\/\/\/?/, '/');
    const basename = path.basename(originalPath);
    tempFilePath = path.join(os.tmpdir(), `vscode-stc-${process.pid}-${basename}`);
    fs.writeFileSync(tempFilePath, textDocument.getText());

    connection.console.log(`Validating: ${originalPath} (using temp: ${tempFilePath})`);

    const output = execSync(`${settings.compilerPath} "${tempFilePath}" 2>&1`, {
      encoding: 'utf-8',
      timeout: 5000
    });

    // Check if compilation was successful
    if (output.includes('Parsing complete')) {
      // No errors
      connection.sendDiagnostics({ uri: textDocument.uri, diagnostics: [] });
      return;
    }

  } catch (error: any) {
    // Parse compiler errors from stderr/stdout
    const errorOutput = error.stderr || error.stdout || error.message;
    connection.console.log(`Compiler output: ${errorOutput}`);

    // stcc error format: /path/to/file.stc:line:column error: message
    // Only match .stc files to filter out Ada compiler stack traces (*.adb files)
    const errorPattern = /([^:\s]+\.stc):(\d+):(\d+)\s+error:\s+(.+?)(?=\n|$)/g;

    let match;
    while ((match = errorPattern.exec(errorOutput)) !== null) {
      const [, filepath, lineStr, columnStr, message] = match;
      const line = parseInt(lineStr) - 1; // VSCode uses 0-based line numbers
      const column = parseInt(columnStr) - 1;

      const diagnostic: Diagnostic = {
        severity: DiagnosticSeverity.Error,
        range: {
          start: { line, character: column },
          end: { line, character: column + Math.max(1, message.length / 4) }
        },
        message: message.trim(),
        source: 'stcc'
      };

      diagnostics.push(diagnostic);
    }

    connection.console.log(`Found ${diagnostics.length} diagnostic(s)`);
  } finally {
    // Clean up temporary file
    if (tempFilePath && fs.existsSync(tempFilePath)) {
      try {
        fs.unlinkSync(tempFilePath);
      } catch (e) {
        connection.console.error(`Failed to delete temp file: ${tempFilePath}`);
      }
    }
  }

  // Send the computed diagnostics to VSCode.
  connection.sendDiagnostics({ uri: textDocument.uri, diagnostics });
}

// This handler provides completion items
connection.onCompletion(
  (_textDocumentPosition: TextDocumentPositionParams): CompletionItem[] => {
    // Return a list of stC keywords and common types
    return [
      // Control flow keywords
      { label: 'if', kind: CompletionItemKind.Keyword },
      { label: 'else', kind: CompletionItemKind.Keyword },
      { label: 'while', kind: CompletionItemKind.Keyword },
      { label: 'for', kind: CompletionItemKind.Keyword },
      { label: 'switch', kind: CompletionItemKind.Keyword },
      { label: 'case', kind: CompletionItemKind.Keyword },
      { label: 'return', kind: CompletionItemKind.Keyword },
      { label: 'break', kind: CompletionItemKind.Keyword },
      { label: 'continue', kind: CompletionItemKind.Keyword },

      // Type keywords
      { label: 'type', kind: CompletionItemKind.Keyword },
      { label: 'subtype', kind: CompletionItemKind.Keyword },
      { label: 'range', kind: CompletionItemKind.Keyword },
      { label: 'modular', kind: CompletionItemKind.Keyword },
      { label: 'struct', kind: CompletionItemKind.Keyword },
      { label: 'union', kind: CompletionItemKind.Keyword },
      { label: 'enum', kind: CompletionItemKind.Keyword },

      // Module keywords
      { label: 'module', kind: CompletionItemKind.Keyword },
      { label: 'import', kind: CompletionItemKind.Keyword },
      { label: 'private', kind: CompletionItemKind.Keyword },

      // Parameter modes
      { label: 'in', kind: CompletionItemKind.Keyword },
      { label: 'out', kind: CompletionItemKind.Keyword },
      { label: 'inout', kind: CompletionItemKind.Keyword },

      // Contracts
      { label: 'pre', kind: CompletionItemKind.Keyword },
      { label: 'post', kind: CompletionItemKind.Keyword },
      { label: 'invariant', kind: CompletionItemKind.Keyword },
      { label: 'assert', kind: CompletionItemKind.Keyword },

      // Constants
      { label: 'true', kind: CompletionItemKind.Constant },
      { label: 'false', kind: CompletionItemKind.Constant },
      { label: 'machine_width', kind: CompletionItemKind.Constant },

      // Primitive types
      { label: 'void', kind: CompletionItemKind.TypeParameter },
      { label: 'bool', kind: CompletionItemKind.TypeParameter },
      { label: 'char', kind: CompletionItemKind.TypeParameter }
    ];
  }
);

// This handler resolves additional information for the item selected in the completion list.
connection.onCompletionResolve(
  (item: CompletionItem): CompletionItem => {
    // Add documentation for keywords
    if (item.label === 'module') {
      item.detail = 'Module declaration';
      item.documentation = 'Declares a new module: module name { ... }';
    } else if (item.label === 'type') {
      item.detail = 'Type declaration';
      item.documentation = 'Declares a new type: type range 0 .. 255 byte_t;';
    } else if (item.label === 'subtype') {
      item.detail = 'Subtype declaration';
      item.documentation = 'Declares a constrained subtype: subtype int_t range 0 .. 100 natural_t;';
    }
    return item;
  }
);

// Document symbols handler for code navigation
connection.onDocumentSymbol(
  (params: DocumentSymbolParams): SymbolInformation[] => {
    const document = documents.get(params.textDocument.uri);
    if (!document) {
      return [];
    }

    const symbols: SymbolInformation[] = [];
    const text = document.getText();
    const lines = text.split('\n');

    // Simple regex-based symbol extraction
    // Match type declarations: type ... identifier;
    const typePattern = /type\s+(range|modular|struct|union|enum)\s+.+?\s+([a-z_][a-z0-9_]*_t)\s*;/g;
    // Match subtype declarations: subtype ... identifier;
    const subtypePattern = /subtype\s+[a-z_][a-z0-9_]*\s+range\s+.+?\s+([a-z_][a-z0-9_]*_t)\s*;/g;
    // Match function declarations
    const functionPattern = /([a-z_][a-z0-9_]*)\s+([a-z_][a-z0-9_]*)\s*\(/g;

    let match;

    // Find type declarations
    while ((match = typePattern.exec(text)) !== null) {
      const name = match[2];
      const offset = match.index;
      const position = document.positionAt(offset);

      symbols.push({
        name: name,
        kind: SymbolKind.Struct,
        location: Location.create(
          params.textDocument.uri,
          Range.create(position, position)
        )
      });
    }

    // Find subtype declarations
    while ((match = subtypePattern.exec(text)) !== null) {
      const name = match[1];
      const offset = match.index;
      const position = document.positionAt(offset);

      symbols.push({
        name: name,
        kind: SymbolKind.TypeParameter,
        location: Location.create(
          params.textDocument.uri,
          Range.create(position, position)
        )
      });
    }

    // Find function declarations
    while ((match = functionPattern.exec(text)) !== null) {
      const returnType = match[1];
      const name = match[2];
      const offset = match.index;
      const position = document.positionAt(offset);

      symbols.push({
        name: name,
        kind: SymbolKind.Function,
        location: Location.create(
          params.textDocument.uri,
          Range.create(position, position)
        )
      });
    }

    return symbols;
  }
);

// Go to Definition handler
connection.onDefinition(
  (params: TextDocumentPositionParams): Location | null => {
    const document = documents.get(params.textDocument.uri);
    if (!document) {
      return null;
    }

    const text = document.getText();
    const offset = document.offsetAt(params.position);

    // Find the word at the cursor position
    const wordPattern = /[a-z_][a-z0-9_]*/gi;
    let currentWord: string | null = null;

    // Find word boundaries around cursor
    const lineText = document.getText({
      start: { line: params.position.line, character: 0 },
      end: { line: params.position.line + 1, character: 0 }
    });

    const lineOffset = document.offsetAt({ line: params.position.line, character: 0 });
    const charInLine = offset - lineOffset;

    let match;
    while ((match = wordPattern.exec(lineText)) !== null) {
      if (match.index <= charInLine && (match.index + match[0].length) >= charInLine) {
        currentWord = match[0];
        break;
      }
    }

    if (!currentWord) {
      return null;
    }

    // Search for type declarations: type ... <name>;
    const typePattern = new RegExp(
      `type\\s+(range|modular|struct|union|enum)\\s+[^;]+?\\s+(${currentWord})\\s*;`,
      'g'
    );

    // Search for subtype declarations: subtype ... <name>;
    const subtypePattern = new RegExp(
      `subtype\\s+[a-z_][a-z0-9_]*\\s+range\\s+[^;]+?\\s+(${currentWord})\\s*;`,
      'g'
    );

    // Search for function declarations: <type> <name>(
    const functionPattern = new RegExp(
      `[a-z_][a-z0-9_]*\\s+(${currentWord})\\s*\\(`,
      'g'
    );

    // Try to find type declaration
    let foundMatch = typePattern.exec(text);
    if (foundMatch) {
      const position = document.positionAt(foundMatch.index);
      return Location.create(
        params.textDocument.uri,
        Range.create(position, position)
      );
    }

    // Try to find subtype declaration
    foundMatch = subtypePattern.exec(text);
    if (foundMatch) {
      const position = document.positionAt(foundMatch.index);
      return Location.create(
        params.textDocument.uri,
        Range.create(position, position)
      );
    }

    // Try to find function declaration
    foundMatch = functionPattern.exec(text);
    if (foundMatch) {
      const position = document.positionAt(foundMatch.index);
      return Location.create(
        params.textDocument.uri,
        Range.create(position, position)
      );
    }

    return null;
  }
);

// Make the text document manager listen on the connection
// for open, change and close text document events
documents.listen(connection);

// Listen on the connection
connection.listen();
