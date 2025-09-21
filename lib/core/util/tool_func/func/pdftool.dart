part of '../tool.dart';

/// Tool for creating and manipulating PDF documents.
final class TfPdfManager extends ToolFunc {
  static const instance = TfPdfManager._();

  const TfPdfManager._()
      : super(
          name: 'pdfmanager',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'description': "The PDF operation: 'create', 'modify', 'extract', or 'find'.",
              },
              'inputId': {
                'type': 'string',
                'description':
                    "The ID of an existing file (usually a PDF, but can be an image, font, etc.). Required for 'modify', 'extract', and 'find' actions.",
              },
              'fileName': {
                'type': 'string',
                'description': "The desired output filename for the new or modified PDF (e.g., 'report.pdf').",
              },
              // Create action parameters
              'text': {
                'type': 'string',
                'description': "Text content to add to a new or existing PDF.",
              },
              'imageIds': {
                'type': 'array',
                'items': {'type': 'string'},
                'description': "A list of image file IDs to insert into a PDF.",
              },
              'tableData': {
                'type': 'object',
                'properties': {
                  'headers': { 'type': 'array', 'items': {'type': 'string'} },
                  'rows': { 'type': 'array', 'items': { 'type': 'array', 'items': {'type': 'string'} } }
                },
                'description': "Data for creating a table, including 'headers' and 'rows'.",
              },
              'listData': {
                'type': 'object',
                'properties': {
                  'items': { 'type': 'array', 'items': {'type': 'string'} },
                  'subItems': { 'type': 'object' }
                },
                'description': "Data for creating a bulleted/numbered list. 'items' is a list of strings. 'subItems' is a map of parent index to a list of sub-item strings.",
              },
              // Modify action parameters
              'pageIndex': {
                'type': 'integer',
                'description': "The zero-based page number to perform a modification on.",
                'default': 0
              },
              'removePageIndex': {
                'type': 'integer',
                'description': "The zero-based page number to remove from a PDF.",
              },
              'addBookmarkTitle': {
                'type': 'string',
                'description': "The title for a new bookmark to add to a PDF.",
              },
              'userPassword': {
                'type': 'string',
                'description': "A user password to encrypt the PDF with.",
              },
              'ownerPassword': {
                'type': 'string',
                'description': "An owner password to encrypt the PDF with.",
              },
               'pfxId': {
                 'type': 'string',
                 'description': "The file ID of a PFX certificate for signing a PDF.",
               },
               'pfxPassword': {
                 'type': 'string',
                 'description': "The password for the PFX certificate.",
               },
              // Find/Extract action parameters
              'queries': {
                'type': 'array',
                'items': {'type': 'string'},
                'description': "A list of text strings to search for within a PDF. Used with 'find' action.",
              },
            },
            'required': ['action'],
          },
        );

  @override
  String get description => '''
Creates, modifies, and extracts data from PDF files.
You can create a complex PDF in a single step by providing text, images, tables, etc.
When creating or modifying, it returns the file ID of the new PDF.

**Actions and Key Parameters:**
1.  **'create'**: Builds a new PDF from scratch.
    - `fileName`: (Required) The name of the output file.
    - `text`: Add simple or long-form text.
    - `imageIds`: A list of image file IDs to include.
    - `tableData`: An object with 'headers' and 'rows' to create a table.
    - `listData`: An object with 'items' to create a list.
    - ... and many other options for fonts, headers, footers, forms.
2.  **'modify'**: Edits an existing PDF.
    - `inputId`: (Required) The ID of the PDF to modify.
    - `fileName`: (Required) The name for the new, modified file.
    - `text`: Add new text to a specific `pageIndex`.
    - `removePageIndex`: Remove a page.
    - `userPassword`: Encrypt the PDF.
    - `pfxId`: Sign the PDF.
3.  **'extract'**: Extracts all text from a PDF into a new .txt file.
    - `inputId`: (Required) The ID of the PDF to extract from.
    - `fileName`: (Optional) The name of the output .txt file.
4.  **'find'**: Finds all occurrences of text in a PDF and saves results to a .json file.
    - `inputId`: (Required) The ID of the PDF to search in.
    - `queries`: (Required) A list of words/phrases to find.
    - `fileName`: (Optional) The name of the output .json file.
''';

  @override
  String get l10nName => "pdfmanager";

  // In a real implementation, you would need Riverpod or another way to get the Provider.
  // This is a placeholder for how you would access your service.
  // For simplicity, we'll assume a global or passed-in instance.
  // final pdfHelper = ref.watch(pdfCreationHelperProvider);

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    // In your actual app, you'll get this from Riverpod.
    final pdfHelper = PdfCreationHelper(FileIndexService.instance);
    
    final action = args['action'] as String?;
    if (action == null) {
      return [ChatContent.text("Error: 'action' is a required parameter for pdfManager.")];
    }
    
    final inputId = args['inputId'] as String?;
    final fileName = args['fileName'] as String?;

    // --- Actions that need an inputId ---
    if (action == 'modify' || action == 'extract' || action == 'find') {
      if (inputId == null) {
        return [ChatContent.text("Error: 'inputId' is required for the '$action' action.")];
      }
    }
    
    // --- Actions that create a new file and need a fileName ---
    if (action == 'create' || action == 'modify') {
        if (fileName == null) {
          return [ChatContent.text("Error: 'fileName' is required for the '$action' action.")];
        }
    }
    
    log("Executing PDF Manager action: '$action'");
    
    try {
      switch (action) {
        // --- CREATE LOGIC ---
        case 'create':
          final text = args['text'] as String?;
          final tableData = args['tableData'] as Map<String, dynamic>?;
          // ... parse all other 'create' parameters ...

          // A real implementation would have a builder pattern or complex conditional logic here.
          // This is a simplified example.
          if (tableData != null) {
            final headers = (tableData['headers'] as List).cast<String>();
            final rows = (tableData['rows'] as List).map((r) => (r as List).cast<String>()).toList();
            final newId = await pdfHelper.addTablesPdfAndIndex(headers: headers, rows: rows, fileName: fileName!);
            return [ChatContent.text("Created PDF with table. New file ID: $newId")];
          }
          if (text != null) {
              final newId = await pdfHelper.createSimplePdfAndIndex(text: text, fileName: fileName!);
              return [ChatContent.text("Created PDF with text. New file ID: $newId")];
          }
          // ... add more conditions for images, lists, etc.
          return [ChatContent.text("Error: For 'create' action, you must provide content like 'text', 'tableData', etc.")];

        // --- MODIFY LOGIC ---
        case 'modify':
          final textToAdd = args['text'] as String?;
          final removeIdx = args['removePageIndex'] as int?;
          final userPass = args['userPassword'] as String?;
          final ownerPass = args['ownerPassword'] as String?;
          // ... parse all other 'modify' parameters ...

          if (userPass != null && ownerPass != null) {
            final newId = await pdfHelper.encryptPdfFileAndIndex(inputId: inputId!, userPassword: userPass, ownerPassword: ownerPass, fileName: fileName!);
            return [ChatContent.text("Encrypted PDF. New file ID: $newId")];
          }
          if (textToAdd != null) {
             final pageIndex = args['pageIndex'] as int? ?? 0;
             final newId = await pdfHelper.loadAndModifyExistingAndIndex(inputId: inputId!, text: textToAdd, pageIndex: pageIndex, fileName: fileName!);
             return [ChatContent.text("Modified PDF with new text. New file ID: $newId")];
          }
           if (removeIdx != null) {
             final newId = await pdfHelper.addRemovePageFromExistingAndIndex(inputId: inputId!, removePageIndex: removeIdx, fileName: fileName!);
             return [ChatContent.text("Modified PDF by removing page. New file ID: $newId")];
           }
           // ... add more conditions ...
           return [ChatContent.text("Error: For 'modify' action, you must provide a modification like 'text', 'removePageIndex', 'userPassword', etc.")];

        // --- EXTRACT/FIND LOGIC ---
        case 'extract':
           final newId = await pdfHelper.extractTextFromPdfAndIndex(inputId: inputId!, fileName: fileName ?? 'extracted_text.txt');
           return [ChatContent.text("Extracted text from PDF. New text file ID: $newId")];

        case 'find':
            final queries = (args['queries'] as List?)?.cast<String>();
            if (queries == null || queries.isEmpty) return [ChatContent.text("Error: 'queries' are required for the 'find' action.")];
            final newId = await pdfHelper.findTextInPdfAndIndex(inputId: inputId!, queries: queries, fileName: fileName ?? 'find_results.json');
            return [ChatContent.text("Found text in PDF. Results saved to new JSON file ID: $newId")];

        default:
          return [ChatContent.text("Error: Unknown action '$action'.")];
      }
    } catch (e) {
      log('PDF Manager Error: $e');
      return [ChatContent.text('An error occurred: $e')];
    }
  }
}