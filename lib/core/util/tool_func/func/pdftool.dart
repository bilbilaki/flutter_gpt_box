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
              'description':
                  "The PDF operation to perform. Must be exactly one of: 'create' (build new PDF from text/tables), 'modify' (edit existing PDF), 'extract' (get text from PDF), or 'find' (search text in PDF). Use only one action per call.",
            },
            'inputId': {
              'type': 'string',
              'description':
                  "The unique file ID of an existing PDF (obtained from 'filemanager' tool via 'list' or 'search'). Required for 'modify', 'extract', and 'find' actions. Always confirm the ID with the user before using.",
            },
            'fileName': {
              'type': 'string',
              'description':
                  "The desired output filename (e.g., 'report.pdf' or 'extracted_text.txt'). Required for 'create' and 'modify'; optional for others (defaults to inferred name). Include .pdf or .txt/.json extension as needed.",
            },
            // Create action parameters (simplified: focus on text and basic tables)
            'text': {
              'type': 'string',
              'description':
                  "The main text content to add to a new PDF (e.g., 'Hello, this is a sample document.'). Required for simple 'create'; optional for 'modify' to add to a specific page.",
            },
            'tableData': {
              'type': 'object',
              'properties': {
                'headers': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'rows': {
                  'type': 'array',
                  'items': {
                    'type': 'array',
                    'items': {'type': 'string'},
                  },
                },
              },
              'description':
                  "Object for creating a table in the PDF: 'headers' as array of strings (e.g., ['Name', 'Age']), 'rows' as 2D array (e.g., [['Alice', '30'], ['Bob', '25']]). Use for 'create' action; confirm data accuracy with user.",
            },
            // Modify action parameters (simplified: text add, page remove, basic encryption)
            'pageIndex': {
              'type': 'integer',
              'description':
                  "Zero-based page number to add text to (for 'modify' with 'text'). Defaults to 0 (first page).",
            },
            'removePageIndex': {
              'type': 'integer',
              'description':
                  "Zero-based page number to remove (for 'modify'). Confirm with user before deleting content.",
            },
            // Find/Extract action parameters
            'queries': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  "Array of text strings to search for (e.g., ['invoice', 'total']). Required for 'find'; results saved as JSON with positions.",
            },
          },
          'required': ['action'],
        },
      );

  @override
  String get description => '''
Use this tool to create, edit, or analyze PDF files when the user explicitly requests it (e.g., "Create a PDF with this table" or "Extract text from that report"). Integrates with 'filemanager'—first use it to list/search for PDFs and get 'inputId', then call this tool. Returns a new 'fileId' for created/modified files, which you can save and offer to the user (e.g., "PDF created—want to read or download it?").
Focus on simple operations to avoid complexity: text-based creation, basic edits, text extraction/search. No advanced features like images, lists, signing, or forms—suggest alternatives if needed (e.g., use 'filemanager' for other files).

**Actions and Usage (Choose Exactly One Per Call):**
1. **'create'**: Builds a new PDF from text or a table.
   - Required: 'fileName' and either 'text' or 'tableData'.
   - Example: For text, provide 'text' string; for table, use 'tableData' object.
   - Response: New 'fileId' and confirmation. Offer: "PDF with your table is ready—should I save it to a folder?"
   - Tip: Keep content concise; confirm details (e.g., "Is this table data correct?").

2. **'modify'**: Edits an existing PDF (adds text, removes page, or encrypts).
   - Required: 'inputId', 'fileName', and one of: 'text' (with optional 'pageIndex'), 'removePageIndex', or 'userPassword'.
   - Example: Add text to page 0, or set 'userPassword' for encryption.
   - Response: New 'fileId' for the modified PDF. Always confirm destructive actions (e.g., "Remove page 2—sure?").
   - Best for simple tweaks; for complex edits, suggest multiple sequential calls.

3. **'extract'**: Pulls all text from a PDF into a new .txt file.
   - Required: 'inputId'; optional 'fileName'.
   - Response: New .txt 'fileId' with extracted content. Summarize for user (e.g., "Extracted ~500 words—want a preview?").

4. **'find'**: Searches for text in a PDF and saves matches to a .json file.
   - Required: 'inputId' and 'queries' array; optional 'fileName'.
   - Response: New .json 'fileId' with search results (positions, contexts). Offer: "Found 3 matches—want the full details?"

**Best Practices to Avoid Errors and Enhance Interaction:**
- Prerequisite: Always get 'inputId' from 'filemanager' first—do not assume file locations.
- Confirmation: Verify all inputs with the user (e.g., "Using report.pdf ID—add text 'Summary'?") to prevent mistakes, especially for modifications or passwords.
- Simplicity: For multi-step PDFs (e.g., text + table), call sequentially (create base, then modify). Limit to 1-2 pages/content to avoid long processing.
- Security: For 'userPassword', ensure it's user-provided and strong; warn about encryption limits (e.g., "This protects viewing but not advanced attacks").
- Handle Responses: Save returned 'fileId's for follow-ups (e.g., use 'filemanager' to read the new PDF). If errors (e.g., invalid ID), inform and retry.
- Multi-File: For batch operations, invoke multiple times—e.g., extract from several PDFs one by one.
- Ethics: Only process user-owned files; summarize sensitive extracts. If feature missing (e.g., images), say: "Can't add images yet—try text instead."

Focus on user-requested PDF tasks—keep it straightforward and safe.''';

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
      return [
        ChatContent.text(
          "Error: 'action' is a required parameter for pdfManager.",
        ),
      ];
    }

    final inputId = args['inputId'] as String?;
    final fileName = args['fileName'] as String?;

    // --- Actions that need an inputId ---
    if (action == 'modify' || action == 'extract' || action == 'find') {
      if (inputId == null) {
        return [
          ChatContent.text(
            "Error: 'inputId' is required for the '$action' action.",
          ),
        ];
      }
    }

    // --- Actions that create a new file and need a fileName ---
    if (action == 'create' || action == 'modify') {
      if (fileName == null) {
        return [
          ChatContent.text(
            "Error: 'fileName' is required for the '$action' action.",
          ),
        ];
      }
    }

    log("Executing PDF Manager action: '$action'");

    try {
      switch (action) {
        // --- CREATE LOGIC (Simplified) ---
        case 'create':
          final text = args['text'] as String?;
          final tableData = args['tableData'] as Map<String, dynamic>?;
          // ... parse all other 'create' parameters ...

          // A real implementation would have a builder pattern or complex conditional logic here.
          // This is a simplified example.
          if (tableData != null) {
            final headers = (tableData['headers'] as List).cast<String>();
            final rows = (tableData['rows'] as List)
                .map((r) => (r as List).cast<String>())
                .toList();
            final newId = await pdfHelper.addTablesPdfAndIndex(
              headers: headers,
              rows: rows,
              fileName: fileName!,
            );
            return [
              ChatContent.text("Created PDF with table. New file ID: $newId"),
            ];
          }
          if (text != null) {
            final newId = await pdfHelper.createSimplePdfAndIndex(
              text: text,
              fileName: fileName!,
            );
            return [
              ChatContent.text("Created PDF with text. New file ID: $newId"),
            ];
          }
          // ... add more conditions for images, lists, etc. (but simplified schema removes them)
          return [
            ChatContent.text(
              "Error: For 'create' action, you must provide content like 'text' or 'tableData'.",
            ),
          ];

        // --- MODIFY LOGIC (Simplified) ---
        case 'modify':
          final textToAdd = args['text'] as String?;
          final removeIdx = args['removePageIndex'] as int?;
          // Removed ownerPassword, pfxId, pfxPassword for simplicity
          // ... parse all other 'modify' parameters ...

          if (textToAdd != null) {
            final pageIndex = args['pageIndex'] as int? ?? 0;
            final newId = await pdfHelper.loadAndModifyExistingAndIndex(
              inputId: inputId!,
              text: textToAdd,
              pageIndex: pageIndex,
              fileName: fileName!,
            );
            return [
              ChatContent.text(
                "Modified PDF with new text. New file ID: $newId",
              ),
            ];
          }
          if (removeIdx != null) {
            final newId = await pdfHelper.addRemovePageFromExistingAndIndex(
              inputId: inputId!,
              removePageIndex: removeIdx,
              fileName: fileName!,
            );
            return [
              ChatContent.text(
                "Modified PDF by removing page. New file ID: $newId",
              ),
            ];
          }
          // ... add more conditions ...
          return [
            ChatContent.text(
              "Error: For 'modify' action, you must provide a modification like 'text', 'removePageIndex', or 'userPassword'.",
            ),
          ];

        // --- EXTRACT/FIND LOGIC ---
        case 'extract':
          final newId = await pdfHelper.extractTextFromPdfAndIndex(
            inputId: inputId!,
            fileName: fileName ?? 'extracted_text.txt',
          );
          return [
            ChatContent.text(
              "Extracted text from PDF. New text file ID: $newId",
            ),
          ];

        case 'find':
          final queries = (args['queries'] as List?)?.cast<String>();
          if (queries == null || queries.isEmpty)
            return [
              ChatContent.text(
                "Error: 'queries' are required for the 'find' action.",
              ),
            ];
          final newId = await pdfHelper.findTextInPdfAndIndex(
            inputId: inputId!,
            queries: queries,
            fileName: fileName ?? 'find_results.json',
          );
          return [
            ChatContent.text(
              "Found text in PDF. Results saved to new JSON file ID: $newId",
            ),
          ];

        default:
          return [
            ChatContent.text(
              "Error: Unknown action '$action'. Supported: 'create', 'modify', 'extract', 'find'.",
            ),
          ];
      }
    } catch (e) {
      log('PDF Manager Error: $e');
      return [ChatContent.text('An error occurred: $e')];
    }
  }
}
